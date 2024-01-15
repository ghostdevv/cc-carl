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
	type: z
		.union([
			z
				.literal('lib')
				.describe(
					"A library package designed to be used in other programs using 'require'.",
				),
			z
				.literal('bin')
				.describe(
					'A binary package allows it to be run using the package name.',
				),
		])
		.describe('Wether this package contains is a library or a binary.'),
	files: z
		.array(
			z.object({
				url: z
					.string()
					.url()
					.describe('The url this file can be downloaded from.'),
				path: z
					.string()
					.describe('The relative path this file will be saved to.'),
			}),
		)
		.describe(
			'An array of files to be downloaded as part of this package.',
		),
	// dependencies: z.array(z.string()),
});

export type Package = z.infer<typeof packageSchema>;

export const repositorySchema = z.object({
	name: nameSchema.describe('The name of this repository.'),
	packages: z.array(packageSchema),
});

export type Repository = z.infer<typeof repositorySchema>;
