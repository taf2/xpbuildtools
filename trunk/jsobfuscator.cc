
#error "This file is not used either"

//#include <stdio.h>
//#include <stdlib.h>
//#include <string.h>
//
///* include the JS engine API header */
//#include <jsapi.h>
//
//static JSBool
//global_enumerate(JSContext *cx, JSObject *obj)
//{
//	return JS_TRUE;
//}
//
//static JSBool
//global_resolve(JSContext *cx, JSObject *obj, jsval id, uintN flags,
//               JSObject **objp)
//{
//	return JS_TRUE;
//}
//
//JSClass global_class = {
//	"global", JSCLASS_NEW_RESOLVE,
//	JS_PropertyStub,  JS_PropertyStub,
//	JS_PropertyStub,  JS_PropertyStub,
//	global_enumerate, (JSResolveOp) global_resolve,
//	JS_ConvertStub,   JS_FinalizeStub
//};
//
//int main(int argc, char **argv)
//{
//  /*set up global JS variables, including global and custom objects */
//  //JSVersion version;
//  JSRuntime *rt;
//  JSContext *cx;
//  JSObject  *glob;
//
//  /* initialize the JS run time, and return result in rt */
//  rt = JS_NewRuntime(8L * 1024L * 1024L);
//
//  /* if rt does not have a value, end the program here */
//  if (!rt)
//    return 1;
//
//  /* establish a context */
//  cx = JS_NewContext(rt, 8192);
//
//  /* if cx does not have a value, end the program here */
//  if (cx == NULL)
//    return 1;
//
//	printf( "created context\n" );
//
//	glob = JS_NewObject(cx, &global_class, NULL, NULL);
//	if (!glob)
//		return 1;
//
//	printf( "created global object\n" );
//
//  /* initialize the built-in JS objects and the global object */
//  if( !JS_InitStandardClasses(cx, glob) )
//		return 1;
//
//	JSScript *js = JS_CompileFile( cx, glob, "rectest.js" );
//	if( !js )
//		return 1;
//	printf( "compiled script\n" );
//
//	JSString *jsstr = JS_DecompileScript( cx, js, "rectest.js", 0 );
//	if( !jsstr )
//		return 1;
//
//	printf( "decompiled script\n%s", JS_GetStringBytes( jsstr ) );
//		
//
//	JS_DestroyContext(cx);
//  /* Before exiting the application, free the JS run time */
//  JS_DestroyRuntime(rt);
//
//	return 0;
//
//}
//
