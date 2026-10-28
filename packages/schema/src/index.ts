import * as v from 'valibot';

const SEMVER_REGEX =
	/(?<=^v?|\sv?)(?:(?:0|[1-9]\d{0,9}?)\.){2}(?:0|[1-9]\d{0,9})(?:-(?:--+)?(?:0|[1-9]\d*|\d*[a-z]+\d*)){0,100}(?=$| |\+|\.)(?:(?<=-\S+)(?:\.(?:--?|[\da-z-]*[a-z-]\d*|0|[1-9]\d*)){1,100}?)?(?!\.)(?:\+(?:[\da-z]\.?-?){1,100}?(?!\w))?(?!\+)/;

// todo alphanumeric + - ?
const nameSchema = v.pipe(
	v.string(),
	v.minLength(1),
	v.maxLength(32),
	v.regex(/^[\w-]+$/),
);

export const PackageSchema = v.object({
	name: v.pipe(nameSchema, v.description('The name of the package.')),
	version: v.pipe(
		v.string(),
		v.regex(SEMVER_REGEX),
		v.description('The current version of the package.'),
	),
	cli: v.nullish(
		v.pipe(
			v.string(),
			v.description(
				'If your package has a cli entry point, the name of the file to be run.',
			),
		),
	),
	files: v.pipe(
		v.array(
			v.object({
				url: v.pipe(
					v.string(),
					v.url(),
					v.description('The url this file can be downloaded from.'),
				),
				path: v.pipe(
					v.string(),
					v.description(
						'The relative path this file will be saved to.',
					),
				),
			}),
		),
		v.description(
			'An array of files to be downloaded as part of this package.',
		),
	),
	// dependencies: v.array(v.string()),
});

export type Package = v.InferOutput<typeof PackageSchema>;
export type PackageSchema = typeof PackageSchema;

export const RepositorySchema = v.object({
	name: v.pipe(nameSchema, v.description('The name of this repository.')),
	packages: v.array(PackageSchema),
});

export type Repository = v.InferOutput<typeof RepositorySchema>;
export type RepositorySchema = typeof RepositorySchema;
