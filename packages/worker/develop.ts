import { serveStatic } from 'hono/cloudflare-workers';
import server from './src/index';

server.get(
	'/source/*',
	serveStatic({
		rewriteRequestPath: (path) => path.slice(7),
	}),
);

export default server;
