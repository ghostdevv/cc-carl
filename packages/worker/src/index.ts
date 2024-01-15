import { getRepository } from './repositories';
import { error, fail } from './utils';
import { logger } from 'hono/logger';
import type { Env } from './types';
import { cors } from 'hono/cors';
import { Hono } from 'hono';

const server = new Hono<Env>();

server.use('*', logger());
server.use('*', cors({ origin: '*' }));

//? File downloading proxy
server.get('/file', async (c) => {
	const { url } = c.req.query();
	if (!url) throw fail('Missing url query parameter');

	const response = await fetch(url);
	if (!response.ok || !response.body) throw error(400, 'Failed to fetch file');

	return c.body(response.body);
});

//? Get package information
server.get('/get/:repository/:package', async (c) => {
	const workerURL = new URL(c.req.url);

	const repository = await getRepository(
		c.req.param('repository'),
		c.env.REPOSITORY_CACHE,
		`${workerURL.origin}/file`,
	);

	const pkg = repository.packages.find((p) => p.name == c.req.param('package'));
	if (!pkg) throw fail('Package not found');

	return c.json(pkg);
});

export default server;
