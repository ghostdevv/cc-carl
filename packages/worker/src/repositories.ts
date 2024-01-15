import { repositorySchema } from '@carl/schema';
import { ofetch } from 'ofetch';
import { fail } from './utils';

export const defaultRepositories = Object.freeze({
	glib: 'https://raw.githubusercontent.com/ghostdevv/cc-glib/main/carl-repo.json',
}) as Record<string, string>;

// function normaliseURL(urlString: string) {
// 	const url = new URL(urlString);
// 	url.protocol = 'https';
// 	return url.toString();
// }

export async function getRepository(name: string, downloadProxyURL: string) {
	const definitionUrl: string | undefined = defaultRepositories[name];
	if (!definitionUrl) throw fail(`Repository ${name} not found`);

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

	return definition;
}
