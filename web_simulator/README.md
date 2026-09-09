# HCP Profiling Web Simulator / Interactive Preview

This folder contains the browser-based test environment for the HCP Profiling application.

## Contents
- `index.html`: Interactive web simulator UI mimicking mobile device screens.
- `app.js`: Application logic and ERPNext API connectivity.
- `mock_data.js`: Embedded mock database representing real ERPNext records.
- `style.css`: Styles for the simulator and mobile frame.
- `server.ps1`: Lightweight local PowerShell web server for hosting the simulator.

## How to Run
From PowerShell, execute:
```powershell
powershell -ExecutionPolicy Bypass -File .\web_simulator\server.ps1
```
Then navigate to `http://localhost:8080` in your web browser.
