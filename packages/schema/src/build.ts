import { writeFile, mkdir, readFile } from 'node:fs/promises';
import { RepositorySchema, PackageSchema } from './index.ts';
import { toJsonSchema } from '@valibot/to-json-schema';
import { join } from 'node:path';
import prettier from 'prettier';
import * as v from 'valibot';

const PRETTIER_CONFIG_FILE = join(import.meta.dirname, '../../../.prettierrc');
const SCHEMA_DIR = join(import.meta.dirname, '../json-schema');

const prettierCfg = JSON.parse(await readFile(PRETTIER_CONFIG_FILE, 'utf-8'));
await mkdir(SCHEMA_DIR, { recursive: true });

async function writeSchema(name: string, schema: v.ObjectSchema<any, any>) {
	const patchedSchema = v.object({
		...schema.entries,
		$schema: v.optional(v.string()),
	});

	const jsonSchema = toJsonSchema(patchedSchema, { target: 'draft-2020-12' });

	const formatted = await prettier.format(
		JSON.stringify(jsonSchema, null, 2),
		{ ...prettierCfg, parser: 'json' },
	);

	await writeFile(`${SCHEMA_DIR}/${name}.json`, formatted, 'utf-8');
}

await writeSchema('repository', RepositorySchema);
await writeSchema('package', PackageSchema);
