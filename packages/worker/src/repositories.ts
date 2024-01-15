import { Repository, repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail } from './utils';
import { Env } from './types';

export const defaultRepositories: Record<string, string> = Object.freeze({
	glib: 'https://raw.githubusercontent.com/ghostdevv/cc-glib/main/carl-repo.json',
});

// function normaliseURL(urlString: string) {
// 	const url = new URL(urlString);
// 	url.protocol = 'https';
// 	return url.toString();
// }

interface RepositoryCacheValue {
	repository: Repository;
	expires: number;
}

export async function getRepository(
	name: string,
	cache: Env['Bindings']['REPOSITORY_CACHE'],
	downloadProxyURL: string,
): Promise<Repository> {
	const definitionUrl: string | undefined = defaultRepositories[name];
	if (!definitionUrl) throw fail(`Repository ${name} not found`);

	const cacheValue = await cache.get(definitionUrl);

	if (cacheValue) {
		const { expires, repository } = JSON.parse(cacheValue) as RepositoryCacheValue;
		if (expires > Date.now()) return repository;
	}

	const rawDefinition = await ofetch(definitionUrl, {
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

	await cache.put(
		definitionUrl,
		JSON.stringify({
			repository: definition,
			expires: Date.now() + 300000, // five minutes,
		}),
	);

	return definition;
}
