import { Repository, repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail } from './utils';
import { Env } from './types';

export const defaultRepositories = Object.freeze({
	glib: 'https://raw.githubusercontent.com/ghostdevv/cc-glib/main/carl-repo.json',
	carl: 'https://raw.githubusercontent.com/ghostdevv/cc-carl/main/carl-repo.json',
});

function isDefaultRepository(name: any): name is keyof typeof defaultRepositories {
	// @ts-ignore bad
	return typeof name == 'string' && defaultRepositories[name];
}

function isURL(url: any): url is string | URL {
	try {
		new URL(url);
		return true;
	} catch {
		return false;
	}
}

interface RepositoryHost {
	name?: string;
	url: string;
}

export function resolveRepositoryHost(
	name?: keyof typeof defaultRepositories | (string & {}),
	customURL?: string,
): RepositoryHost {
	if (isDefaultRepository(name)) {
		return {
			name,
			url: defaultRepositories[name],
		};
	}

	if (!isURL(customURL)) {
		throw fail('Custom repository URL is invalid');
	}

	return { name, url: customURL };
}

interface RepositoryCacheValue {
	repository: Repository;
	expires: number;
}

export async function getRepository(
	host: RepositoryHost,
	cache: Env['Bindings']['REPOSITORY_CACHE'],
	downloadProxyURL: string,
): Promise<Repository> {
	const cacheValue = await cache.get(host.url);

	if (cacheValue) {
		const { expires, repository } = JSON.parse(cacheValue) as RepositoryCacheValue;

		if (expires > Date.now()) {
			if (host.name && repository.name != host.name) {
				throw fail('Repository name mismatch');
			}

			return repository;
		}
	}

	const rawDefinition = await ofetch(host.url, {
		responseType: 'json',
		headers: {
			Accept: 'application/json',
		},
	});

	const definition = await repositorySchema.parseAsync(rawDefinition);

	if (host.name && definition.name != host.name) {
		throw fail('Repository name mismatch');
	}

	definition.packages = definition.packages.map((pkg) => {
		return {
			...pkg,
			files: pkg.files.map((file) => ({
				url: `${downloadProxyURL}?url=${encodeURIComponent(file.url)}`,
				path: file.path,
			})),
		};
	});

	await cache.put(
		host.url,
		JSON.stringify({
			repository: definition,
			expires: Date.now() + 300000, // five minutes,
		}),
	);

	return definition;
}
