import type { Env as HonoEnv } from 'hono';

export interface Env extends HonoEnv {
	Bindings: {
		REPOSITORY_CACHE: KVNamespace;
	};
}
