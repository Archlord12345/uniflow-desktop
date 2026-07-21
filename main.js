const { app, BrowserWindow, utilityProcess } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

let mainWindow;
let backendProcess;

function startBackend() {
  // Spawns the packaged NestJS backend
  const backendPath = path.join(__dirname, 'backend', 'main.js');
  
  backendProcess = spawn('node', [backendPath], {
    env: { ...process.env, PORT: '3000', NODE_ENV: 'production' }
  });

  backendProcess.stdout.on('data', (data) => {
    console.log(`[Backend]: ${data}`);
  });

  backendProcess.stderr.on('data', (data) => {
    console.error(`[Backend Error]: ${data}`);
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  // Load the Flutter desktop app index / local view
  // In production, we point it to the built Flutter desktop build, 
  // or use a local web page communicating with localhost:3000
  mainWindow.loadURL('http://localhost:3000/api/docs'); 

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  startBackend();
  setTimeout(createWindow, 2000); // Give the NestJS server some time to start
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    if (backendProcess) backendProcess.kill();
    app.quit();
  }
});
