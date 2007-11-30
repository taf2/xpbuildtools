#ifndef GNU_GETLINE_H
#define GNU_GETLINE_H

#ifdef WIN32

#ifdef __cplusplus
extern "C" 
{
#endif
#ifdef _MSC_VER
	typedef long ssize_t;
#endif

#ifdef _MSC_VER
__declspec( dllexport )
#endif
ssize_t
getdelim( char **lineptr, size_t *n, int delim, FILE *stream );

#ifdef _MSC_VER
__declspec( dllexport )
#endif
ssize_t
getline( char **lineptr, size_t *n, FILE *stream );

#ifdef __cplusplus
}
#endif

#endif

#endif
