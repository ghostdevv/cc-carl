import { Repository, repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail, isURL } from './utils';
import { Env } from './types';

interface RepositoryCacheValue {
	repository: Repository;
	expires: number;
}

export async function getRepository(
	repositoryUrl: string,
	cache: Env['Bindings']['REPOSITORY_CACHE'],
	downloadProxyURL: string,
): Promise<Repository> {
	if (!isURL(repositoryUrl)) throw fail('Repository URL is invalid');

	const cacheValue = await cache.get(repositoryUrl);

	if (cacheValue) {
		const { expires, repository } = JSON.parse(cacheValue) as RepositoryCacheValue;

		if (expires > Date.now()) return repository;
	}

	const rawDefinition = await ofetch(repositoryUrl, {
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
					new URL(file.url, repositoryUrl).href, // allow relative URLs
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
		repositoryUrl,
		JSON.stringify({
			repository: definition,
			expires: Date.now() + 300000, // five minutes,
		}),
	);

	return definition;
}
