import { repositorySchema, packageSchema } from './index';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { writeFile, mkdir } from 'node:fs/promises';
import { type AnyZodObject, z } from 'zod';
import { join } from 'desm';

const SCHEMA_DIR = join(import.meta.url, '../json-schema');

await mkdir(SCHEMA_DIR, { recursive: true });

async function writeSchema(name: string, zodSchema: AnyZodObject) {
	const schema = zodSchema.extend({ $schema: z.string() });

	await writeFile(
		`${SCHEMA_DIR}/${name}.json`,
		JSON.stringify(zodToJsonSchema(schema), null, 2),
		'utf-8',
	);
}

await writeSchema('repository', repositorySchema);
await writeSchema('package', packageSchema);
