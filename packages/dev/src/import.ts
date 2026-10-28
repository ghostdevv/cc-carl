import { createForges, github, gitlab, tangled } from 'forges';
import { fail, getRepoDefinition } from './shared.ts';
import type { Handler } from 'sade';
import { extname } from 'node:path';
import { log } from '@clack/prompts';

const forges = createForges([github(), gitlab(), tangled()]);

export const run: Handler = async (repository, { prefix }) => {
	if (typeof repository !== 'string') {
		fail('repository arg should be a string');
	}

	if (typeof prefix !== 'string') {
		fail('prefix arg should be a string');
	}

	if (prefix.trim().length === 0) {
		fail('prefix should be at least 1 char long');
	}

	const repo = await getRepoDefinition();

	const forge = forges.parseUrl(repository);

	if (!forge) {
		fail('failed to parse git forge url');
	}

	const name = forge.repo.name.toLowerCase();
	let pkg = repo.packages.find((pkg) => pkg.name === name);

	if (!pkg) {
		pkg = { name, version: '', cli: null, files: [] };
		repo.packages.push(pkg);
	}

	const commits = await forge.provider.commits
		.list(forge.repo, { perPage: 1 })
		.page();

	const latestCommit = commits.items.at(0);
	if (!latestCommit) fail('unable to find latest commit');

	const tree = forge.provider.contents.tree(forge.repo, { recursive: true });

	for await (const entry of tree) {
		// todo handle submodules & symlinks
		if (entry.type !== 'file') continue;
		if (extname(entry.path) !== '.lua') continue;
		if (entry.path.includes('test')) continue;

		const url = forge.provider.urlFor({
			raw: { repo: forge.repo, path: entry.path, at: latestCommit.sha },
		});

		if (!url) {
			fail(`file entry '${entry.path}' created no url`);
		}

		const file = pkg.files.find((file) => file.path === entry.path);

		if (file) {
			file.url = url;
		} else {
			pkg.files.push({ path: entry.path, url });
		}
	}

	if (!pkg.files.length) {
		fail('no files found');
	}

	const latestDate =
		latestCommit.committer?.date ?? latestCommit.author?.date ?? new Date();

	const versionTimestamp = latestDate
		.toISOString()
		.replace(/\D/g, '')
		.slice(0, 14);

	pkg.version = `0.1.0-${prefix.trim()}.${versionTimestamp}`;

	log.success(`Imported ${pkg.files.length} files as ${pkg.name}`);
	await repo.write();
};
