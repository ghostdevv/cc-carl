import { getRepository } from './repositories';
import { error, fail, isURL } from './utils';
import { logger } from 'hono/logger';
import type { Env } from './types';
import { cors } from 'hono/cors';
import { Hono } from 'hono';

const server = new Hono<Env>();

server.use('*', logger());
server.use('*', cors({ origin: '*' }));

//? Install proxy
server.get('/install', async (c) => {
	const response = await fetch(
		'https://raw.githubusercontent.com/ghostdevv/cc-carl/main/packages/client/installer.lua',
	);

	return c.body(response.body, {
		headers: {
			'Content-Type': 'text/lua',
		},
	});
});

//? File downloading proxy
server.get('/file', async (c) => {
	const { url } = c.req.query();
	if (!url) throw fail('Missing url query parameter');

	const response = await fetch(url);
	if (!response.ok || !response.body) throw error(400, 'Failed to fetch file');

	return c.body(response.body);
});

//? Get package information
server.get('/pkg/:package', async (c) => {
	const workerURL = new URL(c.req.url);

	const repository_url = c.req.query('repository');
	if (!isURL(repository_url)) throw fail('Repository URL is invalid');

	const repository = await getRepository(
		repository_url,
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

server.get('/repo', async (c) => {
	const workerURL = new URL(c.req.url);

	const repository_url = c.req.query('repository');
	if (!isURL(repository_url)) throw fail('Repository URL is invalid');

	const repository = await getRepository(
		repository_url,
		c.env.REPOSITORY_CACHE,
		`${workerURL.origin}/file`,
	);

	return c.json(repository);
});

export default server;
