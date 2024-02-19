import { Repository, repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail } from './utils';
import { Env } from './types';

interface RepositoryCacheValue {
	repository: Repository;
	expires: number;
}

export async function getRepository(
	repository_url: string,
	cache: Env['Bindings']['REPOSITORY_CACHE'],
	downloadProxyURL: string,
): Promise<Repository> {
	const cacheValue = await cache.get(repository_url);

	if (cacheValue) {
		const { expires, repository } = JSON.parse(cacheValue) as RepositoryCacheValue;

		if (expires > Date.now()) return repository;
	}

	const rawDefinition = await ofetch(repository_url, {
		responseType: 'json',
		headers: {
			Accept: 'application/json',
		},
	}).catch(() => {
		throw fail(`Failed to fetch repository definition`);
	});

	const definition = await repositorySchema.parseAsync(rawDefinition);

	definition.packages = definition.packages.map((pkg) => {
		return {
			...pkg,
			files: pkg.files.map((file) => ({
				url: `${downloadProxyURL}?url=${encodeURIComponent(
					new URL(file.url, repository_url).href, // allow relative URLs
				)}`,
				path: file.path,
			})),
		};
	});

	for (const pkg of definition.packages) {
		if (pkg.cli && !pkg.files.find((file) => file.path == pkg.cli)) {
			throw fail('Package CLI not found in files');
		}
	}

	await cache.put(
		repository_url,
		JSON.stringify({
			repository: definition,
			expires: Date.now() + 300000, // five minutes,
		}),
	);

	return definition;
}
