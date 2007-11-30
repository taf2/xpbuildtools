#if defined( LINUX ) || defined( MAXOSX )
#define _GNU_SOURCE
#include <unistd.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined( WIN32 )
#include <io.h>
#include "getline.h"
#endif

int unix2dos( const char *file_name )
{
	char *line;
	unsigned int len = 0;
	char tmpfile[7] = { 'X', 'X', 'X', 'X', 'X', 'X', '\0' };
	FILE *fpin = 0;
	FILE *fpout = 0;
	int read;

	fpin = fopen( file_name, "rb" );
	if( !fpin ){
		return 1;
	}

#if defined( WIN32 )
	fpout = fopen( mktemp( tmpfile ), "wb" );
#else
	fpout = fdopen( mkstemp( tmpfile ), "wb" );
#endif
	if( !fpout ){
		fclose( fpin );
		return 1;
	}

	while( ( read = getline( &line, &len, fpin ) ) != EOF ){
		char *ptr = strstr( line, "\n" );

		if( ptr && ptr != line ){
			--ptr;
			if( *ptr != '\r' ){
				fwrite( line, 1, read -1, fpout );
				fwrite( "\r\n", 1, 2, fpout );
			}
			else{
				fwrite( line, 1, read, fpout );
			}
		}
		else{
			fwrite( line, 1, read, fpout );
			fwrite( "\r\n", 1, 2, fpout );
		}
	}
	fclose( fpin );
	fclose( fpout );

	rename( tmpfile, file_name );

//	printf( "created temporary file copy: %s\n", tmpfile );
	return 0;
}

int main( int argc, char **argv )
{
	int i;
	int ret = 0;
	if( argc == 1 ){
		// read from stdin
	}
	else{
		for( i = 1; i < argc; ++i ){
			ret += unix2dos( argv[i] );
		}
	}
	return ret;
}
