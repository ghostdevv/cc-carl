import { HTTPException } from 'hono/http-exception';

export function error(status: number, error: string) {
	throw new HTTPException(status, {
		res: new Response(JSON.stringify({ error }), {
			status,
			headers: {
				'Content-Type': 'application/json',
			},
		}),
	});
}
