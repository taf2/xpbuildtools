#include <stdio.h>

int main()
{
	int c;
	int p = 0;
	while( (c=getc(stdin)) != EOF ){
		if( c == '\r' )
			continue;
		if( c == '\n' && p != 0 && p != ',' ){
			putc( ' ', stdout );
		}else
			putc( c, stdout );
		p = c;
	}
	return 0;
}
