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

export function success(data: Record<string, any>) {
	return Response.json({ success: true, data }, { status: 200 });
}

export function fail(message: string) {
	return Response.json({ success: false, message }, { status: 200 });
}
