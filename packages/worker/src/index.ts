import { repositories } from './repositories';
import { logger } from 'hono/logger';
import type { Env } from './types';
import { cors } from 'hono/cors';
import { error } from './utils';
import { klona } from 'klona';
import { Hono } from 'hono';

const server = new Hono<Env>();

server.use('*', logger());
server.use('*', cors({ origin: '*' }));

//? File downloading proxy
server.get('/file', async (c) => {
	const { url } = c.req.query();
	if (!url) throw error(400, 'Missing url query parameter');

	const response = await fetch(url);
	if (!response.ok || !response.body) throw error(400, 'Failed to fetch file');

	return c.body(response.body);
});

//? Get package information
server.get('/p/:repository/:package', async (c) => {
	const repository = repositories.find((r) => r.name == c.req.param('repository'));
	if (!repository) throw error(404, 'Repository not found');

	// todo when we don't store repos in ts file don't clone obj like that
	const pkg = klona(repository).packages.find((p) => p.name == c.req.param('package'));
	if (!pkg) throw error(404, 'Package not found');

	const url = new URL(c.req.url);

	pkg.files = pkg.files.map((file) => ({
		url: `${url.origin}/file?url=${encodeURIComponent(file.url)}`,
		path: file.path,
	}));

	return c.json(pkg);
});

export default server;
