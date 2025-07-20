const { app, BrowserWindow } = require('electron');
const path = require('path');
const Bonjour = require('bonjour');
const wrtc = require('electron-webrtc')();
const WebSocket = require('ws');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    frame: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: true,
      contextIsolation: false
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
  let peerConnection;

  wss.on('connection', (ws) => {
    ws.on('message', (message) => {
      const data = JSON.parse(message);
      if (data.type === 'offer') {
        peerConnection = new wrtc.RTCPeerConnection();
        peerConnection.onicecandidate = (event) => {
          if (event.candidate) {
            ws.send(JSON.stringify({ type: 'candidate', candidate: event.candidate }));
          }
        };
        peerConnection.ontrack = (event) => {
          mainWindow.webContents.send('stream', event.streams[0].toURL());
        };
        peerConnection.setRemoteDescription(new wrtc.RTCSessionDescription(data));
        peerConnection.createAnswer().then((answer) => {
          peerConnection.setLocalDescription(answer);
          ws.send(JSON.stringify({ type: 'answer', sdp: answer.sdp }));
        });
      } else if (data.type === 'candidate') {
        peerConnection.addIceCandidate(new wrtc.RTCIceCandidate(data.candidate));
      }
    });
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', function () {
  if (mainWindow === null) createWindow();
});
