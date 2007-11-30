#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

// 
static char *usageMsg = 
"An MS Windows-Only program to do the ShellExecute() call to run a program.\n"+
"Kindof like opening (editing, printing...) a file in gui shell.\n"+
"usage: \n"+
" shellexec.exe -edit aFileName\n"+
" shellexec.exe -explore aFileName\n"+
" shellexec.exe -open aFileName extra params\n"+
" shellexec.exe -print aFileName\n"+
" shellexec.exe aFileName = -open aFileName\n";


static const char *operation( const char *arg, int *off );

int main( int argc, char **argv )
{
	char *param = 0;
	const char *op;
	int i, len = 0, offset, poff = 0;
	if( argc < 2 ){
		fprintf( stderr, usageMsg );
		return 1;
	}
	op = operation( argv[1], &offset );
	// construct param string
	for( i = offset; i < argc; ++i ){
		int plen = strlen( argv[i] ) + 1;
		if( len < plen ){
			if( param == 0 )
				param = malloc( sizeof(char)*plen );
			else{
				len += (plen*2);
				param = realloc( param, sizeof(char)*len );
			}
		}
		memcpy( param+poff, argv[i], plen );
		poff += (plen - 1);
	}
	ShellExecute( NULL, op, argv[offset], param, NULL, SW_SHOWNORMAL );
	free( param );
	return 0;
}


static const char *
operation( const char *arg, int *offset )
{
	if( arg && arg[0] == '-' ){
		*offset = 2;
		return (arg+1);
	}
	else{
		*offset = 1;
		return "open";
	}
}
