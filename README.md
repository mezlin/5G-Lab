# 5G O-RAN Lab & AI Assistant Dashboard

This repository contains the configuration, manifests, and the AI-driven dashboard for the 5G O-RAN Testbed. The testbed integrates components like Open5GS, srsRAN, Prometheus for telemetry, and an AI-powered conversational interface designed to securely monitor and manage the network.

## 1. 5G Lab Deployment

> **Note:** Please refer to the "5G Lab deployment guide" from your Obsidian Vault and paste the comprehensive deployment steps for the core 5G testbed here.

*(Paste Obsidian guide here)*

---

## 2. AI Assistant Dashboard Deployment

The Dashboard is a minimalist, Nokia-themed conversational UI powered by Google's Gemini 2.5 Flash model. It connects to your Kubernetes cluster and Prometheus metrics server to provide real-time, interactive management of your 5G lab.

### Prerequisites & Requirements
- **OS**: Linux VM (Ubuntu/Debian recommended)
- **Kubernetes Access**: The backend requires `kubectl` to be installed and configured with access to the `open5gs` namespace.
- **Python**: Python 3.10+ (Python 3.12 was used in this lab).
- **Network**: The backend must have access to the Prometheus server (default: `http://10.100.125.233:9090`).
- **Google Gemini API Key**: Required for the LLM function calling.

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mezlin/5G-Lab.git
   cd 5G-Lab/dashboard
   ```

2. **Configure the Backend:**
   Navigate to the backend directory and set up a Python virtual environment:
   ```bash
   cd backend
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Set up Environment Variables:**
   Create a `.env` file in the `dashboard/backend` directory:
   ```bash
   echo "GEMINI_API_KEY=your_google_gemini_api_key_here" > .env
   ```

4. **Start the Backend API:**
   Ensure your virtual environment is active, then run the Flask server:
   ```bash
   nohup python app.py > backend.log 2>&1 &
   ```
   *The backend will start on `http://0.0.0.0:5001`.*

5. **Start the Frontend UI:**
   Navigate to the frontend directory and start a simple HTTP server:
   ```bash
   cd ../frontend
   python3 -m http.server 3000
   ```

6. **Access the Dashboard:**
   Open your browser and navigate to `http://<VM_IP>:3000`. You can now chat with the AI about your network state!

### Security Note
The AI is configured to securely propose bash/kubectl commands rather than executing them directly. All state-modifying actions require explicit user confirmation via the UI.
