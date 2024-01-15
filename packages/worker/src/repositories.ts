import { Repository } from '@carl/schema';

// todo build this from a list of things
export const repositories: Repository[] = [
	{
		name: 'glib',
		packages: [
			{
				name: 'neofetch',
				version: '0.1.0',
				type: 'bin',
				files: [
					{
						path: 'neofetch.lua',
						url: 'https://raw.githubusercontent.com/ghostdevv/cc-glib/main/lib/neofetch.lua',
					},
				],
			},
		],
	},
];
