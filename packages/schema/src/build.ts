import { repositorySchema, packageSchema } from './index';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { writeFile, mkdir } from 'node:fs/promises';
import { join } from 'desm';

const SCHEMA_DIR = join(import.meta.url, '../schema');

await mkdir(SCHEMA_DIR, { recursive: true });

await writeFile(
	`${SCHEMA_DIR}/repositorySchema.json`,
	JSON.stringify(zodToJsonSchema(repositorySchema), null, 2),
	'utf-8',
);

await writeFile(
	`${SCHEMA_DIR}/packageSchema.json`,
	JSON.stringify(zodToJsonSchema(packageSchema), null, 2),
	'utf-8',
);
