import { Repository, repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail } from './utils';
import { Env } from './types';

interface RepositoryCacheValue {
	repository: Repository;
	expires: number;
}

export async function getRepository(
	repository: string,
	cache: Env['Bindings']['REPOSITORY_CACHE'],
	downloadProxyURL: string,
): Promise<Repository> {
	const cacheValue = await cache.get(repository);

	if (cacheValue) {
		const { expires, repository } = JSON.parse(cacheValue) as RepositoryCacheValue;

		if (expires > Date.now()) return repository;
	}

	const rawDefinition = await ofetch(repository, {
		responseType: 'json',
		headers: {
			Accept: 'application/json',
		},
	});

	const definition = await repositorySchema.parseAsync(rawDefinition);

	definition.packages = definition.packages.map((pkg) => {
		return {
			...pkg,
			files: pkg.files.map((file) => ({
				url: `${downloadProxyURL}?url=${encodeURIComponent(file.url)}`,
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
		repository,
		JSON.stringify({
			repository: definition,
			expires: Date.now() + 300000, // five minutes,
		}),
	);

	return definition;
}
