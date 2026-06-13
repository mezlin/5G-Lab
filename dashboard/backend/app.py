from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
import json
import subprocess
import os
import uuid

from google import genai

app = Flask(__name__)
CORS(app)

from dotenv import load_dotenv
load_dotenv()

PROMETHEUS_URL = "http://10.100.125.233:9090"
API_KEY = os.getenv("GEMINI_API_KEY", "")
client = genai.Client(api_key=API_KEY)

# Store pending actions in memory
pending_actions = {}

system_prompt = """
You are an O-RAN Network Assistant AI with a white/blue UI. 
You can answer user questions about the network state.

You have complete access to the network. You can query Prometheus metrics and read Kubernetes resources to find out anything you need.
If the user asks you to apply a change, execute a script, scale a deployment, or perform any infrastructure modification, you MUST NOT do it directly. Instead, propose the action.
To propose an action, you must return a valid JSON block embedded in your response formatted exactly like this:
```json
{
  "action_proposed": {
    "command": "kubectl scale deploy/some-deploy --replicas=3 -n open5gs",
    "description": "This will scale the deployment to 3 replicas."
  }
}
```
Always be polite and professional. Never output JSON unless proposing an action. If you propose an action, put the JSON block at the very end of your message.
"""

def query_prometheus(query: str) -> str:
    """Queries Prometheus with a PromQL query. Returns the JSON result data."""
    try:
        res = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query}, timeout=10).json()
        return json.dumps(res.get('data', {}).get('result', []))
    except Exception as e:
        return str(e)

def run_kubectl(command: str) -> str:
    """Runs a read-only kubectl command in the open5gs namespace. Example commands: 'get pods -o wide', 'logs deploy/srsran-gnb -c gnb'"""
    try:
        if any(x in command for x in ["apply", "delete", "edit", "scale", "exec"]):
            return "Error: Do not use modifying commands or exec here. Use action_proposed in your response."
        
        full_cmd = f"kubectl {command} -n open5gs"
        result = subprocess.run(full_cmd, shell=True, capture_output=True, text=True, timeout=15)
        return result.stdout if result.stdout else result.stderr
    except Exception as e:
        return str(e)

def get_prom_metric(query):
    try:
        res = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query}, timeout=5).json()
        if res.get('status') == 'success' and res['data']['result']:
            return float(res['data']['result'][0]['value'][1])
    except Exception as e:
        pass
    return 0.0

@app.route('/api/metrics', methods=['GET'])
def get_metrics():
    active_gnbs = get_prom_metric('count(kube_pod_info{pod=~"srsran-gnb.*"})')
    active_ues = get_prom_metric('sum(ues_active)')

    return jsonify({
        "active_gnbs": int(active_gnbs),
        "active_ues": int(active_ues)
    })

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.json
    user_msg = data.get("message", "")
    
    prompt = f"{system_prompt}\n\nUser: {user_msg}"
    
    try:
        chat_session = client.chats.create(
            model='gemini-2.5-flash',
            config={"tools": [run_kubectl, query_prometheus]}
        )
        response = chat_session.send_message(prompt)
        reply = response.text
        
        # Check if the AI proposed an action
        action_data = None
        action_id = None
        if "```json" in reply:
            try:
                json_str = reply.split("```json")[1].split("```")[0].strip()
                parsed = json.loads(json_str)
                if "action_proposed" in parsed:
                    action_data = parsed["action_proposed"]
                    action_id = str(uuid.uuid4())
                    pending_actions[action_id] = action_data
                    
                    # Remove the json block from the reply text shown to user
                    reply = reply.split("```json")[0].strip()
            except:
                pass
                
        return jsonify({
            "reply": reply,
            "action": action_data,
            "actionId": action_id
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/action/<action_id>/execute', methods=['POST'])
def execute_action(action_id):
    if action_id not in pending_actions:
        return jsonify({"error": "Action not found or already executed"}), 404
        
    action = pending_actions[action_id]
    command = action.get("command", "")
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=False)
        output = result.stdout if result.stdout else result.stderr
        
        # Remove from pending
        del pending_actions[action_id]
        
        return jsonify({"output": output})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
