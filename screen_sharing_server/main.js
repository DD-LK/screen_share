const { app, BrowserWindow } = require('electron');
const path = require('path');
const WebSocket = require('ws');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    frame: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile('index.html');

  mainWindow.on('closed', function () {
    mainWindow = null;
  });
}

app.on('ready', () => {
  createWindow();

  const wss = new WebSocket.Server({ port: 8080 });

  wss.on('connection', (ws) => {
    ws.on('message', (message) => {
      mainWindow.webContents.send('image', message);
    });
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', function () {
  if (mainWindow === null) createWindow();
});
