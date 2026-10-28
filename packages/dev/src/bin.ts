#!/usr/bin/env node
import { version } from '../package.json' with { type: 'json' };
import { run as importCommand } from './import.ts';
import { intro, outro } from '@clack/prompts';
import { styleText } from 'node:util';
import sade from 'sade';

const program = sade('carl');

program.version(version);

program
	.command('import <repository>')
	.describe('Add a git repository to your carl repo')
	.option(
		'--prefix',
		'Prefix added before the date on the generated version',
		'import',
	)
	.action(importCommand);

intro(
	`${styleText(['yellow'], '@carl/')}${styleText(['bold', 'yellow'], 'dev')} ${styleText('dim', `v${version}`)}`,
);

await (program.parse(process.argv) as unknown as Promise<void>);

outro('👋');
