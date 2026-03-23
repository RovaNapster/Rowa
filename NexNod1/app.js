const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 4000;
const SERVICE_ID = process.env.NODE_ID || 'nexnod-unknown';

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            service: SERVICE_ID,
            timestamp: new Date().toISOString(),
            uptime: process.uptime()
        }));
    } else if (req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`<h1>${SERVICE_ID}</h1><p>Service is running on ${os.hostname()}</p>`);
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
    }
});

server.listen(PORT, () => {
    console.log(`[${SERVICE_ID}] Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});

process.on('SIGTERM', () => {
    console.log('[SIGTERM] Gracefully shutting down...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
