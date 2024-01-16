import { getRepository, resolveRepositoryHost } from './repositories';
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
server.get('/pkg/:repository/:package', async (c) => {
	const workerURL = new URL(c.req.url);

	const host = resolveRepositoryHost(
		c.req.param('repository'),
		c.req.query('definitionURL'),
	);

	const repository = await getRepository(
		host,
		c.env.REPOSITORY_CACHE,
		`${workerURL.origin}/file`,
	);

	const pkg = repository.packages.find((p) => p.name == c.req.param('package'));
	if (!pkg) throw fail('Package not found');

	return c.json({
		name: pkg.name,
		repo: repository.name,
		version: pkg.version,
		cli: pkg.cli,
		files: pkg.files,
	});
});

server.get('/repo/:repository?', async (c) => {
	const workerURL = new URL(c.req.url);

	const host = resolveRepositoryHost(
		c.req.param('repository'),
		c.req.query('definitionURL'),
	);

	const repository = await getRepository(
		host,
		c.env.REPOSITORY_CACHE,
		`${workerURL.origin}/file`,
	);

	return c.json(repository);
});

export default server;
