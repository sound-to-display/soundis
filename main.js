const { app, BrowserWindow, desktopCapturer, session } = require('electron');
const path = require('node:path');

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 960,
    height: 720,
    backgroundColor: '#0a0a0a',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  session.defaultSession.setDisplayMediaRequestHandler((request, callback) => {
    desktopCapturer
      .getSources({ types: ['screen'] })
      .then((sources) => {
        callback({ video: sources[0], audio: 'loopback' });
      })
      .catch((error) => {
        console.error('[main] Failed to resolve display media sources:', error);
        callback({ video: null, audio: null });
      });
  });

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
