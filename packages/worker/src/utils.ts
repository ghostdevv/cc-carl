import { HTTPException } from 'hono/http-exception';

export function error(status: number, error: string) {
	return new HTTPException(status, {
		res: new Response(JSON.stringify({ error }), {
			status,
			headers: {
				'Content-Type': 'application/json',
			},
		}),
	});
}

export function success(data: Record<string, any>) {
	return new HTTPException(200, {
		res: Response.json({ success: true, data }, { status: 200 }),
	});
}

export function fail(message: string) {
	return new HTTPException(200, {
		res: Response.json({ success: false, message }, { status: 200 }),
	});
}

export function isURL(url: any): url is string | URL {
	try {
		new URL(url);
		return true;
	} catch {
		return false;
	}
}
