// Javascript Cruncher
// Copyright (c) 2002 by Charles Foster, cfoster.net
//
// Removes all unnessacery spaces, tabs, comments etc
//
// Feel free to use and modify this source and application
// in anyway you like (at your own risk of course) :)

#include<stdio.h>
#include<string.h>
#include<stdlib.h>

const char* _R[] = {"","const", "var ","new ","throw ","typeof ","case ",'\0'};

int js_body=1,					// In main JS execution (no text or comments)
	js_comment_block=0,		// inside /* */
	js_comment=0,					// everything after the // on that line
	js_double=0,					// inside "" - Exceptions: \"
	js_single=0,					// inside '' - Exceptions: \'
	js_regexp=0,					// inside /REGEXP/ - Exceptions: \/
	js_space=0,						// for when a space is needed
	js_else=0,						// after else flag
	js_function=0,				// after function flag
	js_arg=0,							// after break or return flag

	infile_size, i,				// misc bits and pieces
	j=0, buf_p=0,					// for main()

	z,y,l,ok;							// misc bits and pieces for isRkey()
// ------
int isRkey(char* b)
{
	z=0;
	while(_R[++z] != '\0')
	{
		ok=1;
		l=strlen(_R[z]);
		for(y=0;y<l;y++)
		{
			if(_R[z][y] != b[y]) { ok=0; break; }
		}
		if(ok) { return 1; }
	}
	return 0;
}
// ------
int main(int args, char** argv)
{
	FILE* infile;
	FILE* outfile;
	char* buffer;
	char* t_buffer;
	char c;

	if(args != 3) {
		printf("Javascript Cruncher Copyright (c) 2002 Charles Foster\n"
					 "usage: js infile outfile\n"); return 0;
	}
	if(strcmp(argv[1],argv[2]) == 0) {
		printf("I don't want you to over-write your existing js file\n"); return 0; }
	if((infile = fopen(argv[1],"r")) == 0) {
		printf("%s doesn't exist\n",argv[1]); return 0; }
	if((outfile = fopen(argv[2],"w")) == 0) {
		printf("can't write to %s",argv[2]); return 0; }

	fseek(infile,0,SEEK_END);
	infile_size = ftell(infile);
	rewind(infile);
	buffer = (char*)malloc(infile_size);
	while((c = fgetc(infile)) != EOF) { buffer[buf_p++] = c; }
	t_buffer = (char*)malloc(buf_p);
	strcpy(t_buffer,"");
	
	for(i=0;i<buf_p;i++)
	{
		if(js_body)
		{
			if(buffer[i] == '/' && buffer[i+1] == '/') {
				js_body=0; js_comment=1;
			}
			else if(buffer[i] == '/' && buffer[i+1] == '*') {
				js_body=0; js_comment_block=1;
			}
			else if(buffer[i] == '/') {
				t_buffer[j++] = buffer[i];
				js_body=0; js_regexp=1;
			}
			else if(buffer[i] == '"') {
				t_buffer[j++] = buffer[i];
				js_body=0; js_double=1;				
			}
			else if(buffer[i] == '\'') {
				t_buffer[j++] = buffer[i];
				js_body=0; js_single=1;				
			}
			else if(isRkey(&buffer[i])) {
				t_buffer[j++] = buffer[i];
				js_space=1;
			}
			else if(strncmp(&buffer[i],"instanceof",10) == 0) {
				t_buffer[j++] = ' ';
				t_buffer[j++] = buffer[i];
				js_space=1;
			}
			else if(strncmp(&buffer[i],"function",8) == 0) {
				t_buffer[j++] = buffer[i];
				js_space=1;
				js_function=1;
			}
			else if(strncmp(&buffer[i],"else",4) == 0) {
				strncat(&t_buffer[j],&buffer[i],4);
				i+=4;j+=4;
				js_else=1;
			}
			else if(strncmp(&buffer[i],"return",6) == 0) {
				strncat(&t_buffer[j],&buffer[i],6);
				i+=5;j+=6;
				js_arg=1;
			}
			else if(strncmp(&buffer[i],"break",5) == 0) {
				strncat(&t_buffer[j],&buffer[i],5);
				i+=4;j+=5;
				js_arg=1;
			}
			else if(buffer[i] != ' ' && buffer[i] != 0x09 && buffer[i] != '\n')
			{
				/*if(js_else && (strncmp(&buffer[i],"if",2) == 0 || buffer[i] != '{')) {
					t_buffer[j++] = ' ';
				}
				else */if(js_arg && buffer[i] != ';') {
					t_buffer[j++] = ' ';
				}
				else if(js_function && buffer[i] == '(') {
					js_space=0;
				}
				js_else=0;
				js_arg=0;
				t_buffer[j++] = buffer[i];
			}
			else if(buffer[i] == ' ' && js_space && !js_function) {
				t_buffer[j++] = ' ';
				js_space=0;
			}
			else if(buffer[i] == ' ' && js_space && js_function)
			{
				if(buffer[i+1] >= 0x41 && buffer[i+1] <= 0x5A || // A > Z
					 buffer[i+1] >= 0x61 && buffer[i+1] <= 0x7A || // a > z
					 buffer[i+1] == '_')
				{
					t_buffer[j++] = buffer[i];
					js_function=0;
					js_space=0;
				}
			}
		} // !js_body:
		else if(js_comment) {
			if(buffer[i] == '\n') {
				js_comment=0;
				js_body=1;
			}
		}
		else if(js_comment_block) {
			if(buffer[i] == '*' && buffer[i+1] == '/') {
				js_comment_block=0;
				js_body=1;
				i++;
			}
		}
		else if(js_regexp) {
			t_buffer[j++] = buffer[i];
			if(buffer[i] == '/' && buffer[i-1] != '\\') {
				js_body=1;
				js_regexp=0;
			}
		}
		else if(js_double) {
			t_buffer[j++] = buffer[i];
			if(buffer[i] == '"' && buffer[i-1] != '\\') {
				js_body=1;
				js_double=0;
			}
		}
		else if(js_single) {
			t_buffer[j++] = buffer[i];
			if(buffer[i] == '\'' && buffer[i-1] != '\\') {
				js_body=1;
				js_single=0;
			}
		}
	}
	fprintf(outfile,t_buffer);
	fclose(infile);
	fclose(outfile);
	return 0;
}
