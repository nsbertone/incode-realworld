// Same-origin API: CloudFront routes /api/* to the backend, so the browser
// never talks to another host (no CORS, no API URL baked into the build).
import { HttpInterceptorFn } from '@angular/common/http';

export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const apiReq = req.clone({ url: `/api${req.url}` });
  return next(apiReq);
};
