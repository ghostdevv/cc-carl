import { z } from 'zod';

const SEMVER_REGEX =
	/(?<=^v?|\sv?)(?:(?:0|[1-9]\d{0,9}?)\.){2}(?:0|[1-9]\d{0,9})(?:-(?:--+)?(?:0|[1-9]\d*|\d*[a-z]+\d*)){0,100}(?=$| |\+|\.)(?:(?<=-\S+)(?:\.(?:--?|[\da-z-]*[a-z-]\d*|0|[1-9]\d*)){1,100}?)?(?!\.)(?:\+(?:[\da-z]\.?-?){1,100}?(?!\w))?(?!\+)/;

// todo alphanumeric + - ?
const nameSchema = z
	.string()
	.min(1)
	.max(32)
	.regex(/^[\w-]+$/);

export const packageSchema = z.object({
	name: nameSchema.describe('The name of the package.'),
	version: z
		.string()
		.regex(SEMVER_REGEX)
		.describe('The current version of the package.'),
	cli: z
		.string()
		.or(z.null())
		.describe(
			'If your package has a cli entry point, the name of the file to be run.',
		),
	files: z
		.array(
			z.object({
				url: z.string().describe('The url this file can be downloaded from.'),
				path: z
					.string()
					.describe('The relative path this file will be saved to.'),
			}),
		)
		.describe('An array of files to be downloaded as part of this package.'),
	// dependencies: z.array(z.string()),
});

export type Package = z.infer<typeof packageSchema>;

export const repositorySchema = z.object({
	name: nameSchema.describe('The name of this repository.'),
	packages: z.array(packageSchema),
});

export type Repository = z.infer<typeof repositorySchema>;
