from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route('/scale', methods=['POST'])
def scale_gnb():
    data = request.json
    mcores = data.get('target_mcores', 500)
    
    # crictl cpu-quota is in microseconds per 100ms (100000) period.
    # 1 core (1000m) = 100000 quota
    # so quota = mcores * 100
    quota = int(mcores) * 100
    
    print(f"Scaling gNB to {mcores}m (Quota: {quota})")
    
    # 1. Get container ID exactly matching 'gnb'
    try:
        cmd_ps = "crictl ps --name '^gnb$' -q"
        output = subprocess.check_output(cmd_ps, shell=True).decode().strip()
        
        if not output:
            return {"status": "error", "message": "gnb container not found"}, 404
            
        cids = output.split()
        
        # 2. Update cgroups directly via containerd (no restart!)
        for cid in cids:
            cmd_update = f"crictl update --cpu-quota {quota} --cpu-period 100000 {cid}"
            subprocess.check_output(cmd_update, shell=True)
            print(f"Patched container {cid}")
        
        return {"status": "success", "containers_patched": cids, "new_mcores": mcores}
    except Exception as e:
        return {"status": "error", "message": str(e)}, 500

if __name__ == '__main__':
    # Listen on all interfaces so the Jupyter pod can reach it via 10.200.0.1
    app.run(host='0.0.0.0', port=5000)
