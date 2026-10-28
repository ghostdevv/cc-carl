import { RepositorySchema, type Repository } from '@carl/schema';
import { readFile, writeFile } from 'node:fs/promises';
import { format } from '@changesets/format';
import * as find from 'empathic/find';
import { styleText } from 'node:util';
import { log } from '@clack/prompts';
import { relative } from 'node:path';
import { cwd } from 'node:process';
import * as v from 'valibot';

const CLACK_BAR_END = styleText('gray', '\u2514');

/**
 * Print a failure message and exit with 1
 * @param message Failure message
 */
export function fail(...messages: unknown[]): never {
	const message = messages.map(String).join(' ');
	log.message(styleText('red', message), { symbol: CLACK_BAR_END });
	process.exit(1);
}

type JSONValue =
	| string
	| number
	| boolean
	| null
	| JSONValue[]
	| { [key: string]: JSONValue };

async function safeReadJSON(path: string): Promise<JSONValue | Error> {
	try {
		return JSON.parse(await readFile(path, 'utf-8'));
	} catch (error) {
		return Error.isError(error)
			? error
			: new Error('failed to read json', { cause: error });
	}
}

interface RepoDefinition extends Repository {
	/**
	 * The full path of the repo definition on disk
	 */
	__path: string;

	/**
	 * Write the presumably mutated definition back to disk
	 */
	write: () => Promise<void>;
}

/**
 * Finds a `carl-repo.json` in the current or parent directories and parses it.
 * Any errors are printed and the program exists
 */
export async function getRepoDefinition(): Promise<RepoDefinition> {
	const path = find.up('carl-repo.json');
	if (!path) fail('unable to find `carl-repo.json`');

	const json = await safeReadJSON(path);

	if (Error.isError(json)) {
		const message = json.message.replaceAll('\n', '');
		fail(`failed to parse \`${relative(cwd(), path)}\` as json:`, message);
	}

	const parsed = v.safeParse(RepositorySchema, json);

	if (!parsed.success) {
		const message = JSON.stringify(v.flatten(parsed.issues));
		fail(`failed to validate \`${relative(cwd(), path)}\`:`, message);
	}

	// I'm being lazy in such a weird way, will fix later
	(parsed.output as RepoDefinition).__path = path;
	(parsed.output as RepoDefinition).write = async () => {
		const { __path, ...data } = parsed.output as RepoDefinition;
		await writeFile(__path, JSON.stringify(data, null, 2), 'utf-8');
		await format([__path]);
	};

	return parsed.output as RepoDefinition;
}
