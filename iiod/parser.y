%{
/*
 * libiio - Library for interfacing industrial I/O (IIO) devices
 *
 * Copyright (C) 2014 Analog Devices, Inc.
 * Author: Paul Cercueil <paul.cercueil@analog.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * */

#include "ops.h"
#include "parser.h"

#include <string.h>

void yyerror(yyscan_t scanner, const char *msg);
%}

%code requires {
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif

#define YYDEBUG 1

int yylex();
int yylex_init_extra(void *d, yyscan_t *scanner);
int yylex_destroy(yyscan_t yyscanner);

void * yyget_extra(yyscan_t scanner);
void yyset_in(FILE *in, yyscan_t scanner);
void yyset_out(FILE *out, yyscan_t scanner);

#define YY_INPUT(buf,result,max_size) { \
		int c = '*'; \
		size_t n; \
		for ( n = 0; n < max_size && \
			     (c = getc( yyin )) != EOF && c != '\n'; ++n ) \
			buf[n] = (char) c; \
		if ( c == '\n' ) \
			buf[n++] = (char) c; \
		if ( c == EOF && ferror( yyin ) ) \
			YY_FATAL_ERROR( "input in flex scanner failed" ); \
		result = n; \
		} \

}

%define api.pure
%lex-param { yyscan_t scanner }
%parse-param { yyscan_t scanner }

%union {
	char *word;
}

%token SPACE
%token END

%token EXIT
%token HELP
%token PRINT
%token READ
%token READBUF
%token WRITE

%token <word> WORD

%start Line
%%

Line:
	END {
		YYACCEPT;
	}
	| EXIT END {
		struct parser_pdata *pdata = yyget_extra(scanner);
		pdata->stop = true;
		YYACCEPT;
	}
	| HELP END {
		struct parser_pdata *pdata = yyget_extra(scanner);
		fprintf(pdata->out, "Available commands:\n\n"
		"\tHELP\n"
		"\t\tPrint this help message\n"
		"\tEXIT\n"
		"\t\tClose the current session\n"
		"\tPRINT\n"
		"\t\tDisplays a XML string corresponding to the current IIO context\n"
		"\tREAD <device> <attribute>\n"
		"\t\tRead the value of a device's attribute\n"
		"\tWRITE <device> <attribute> <value>\n"
		"\t\tSet the value of a device's attribute\n"
		"\tREADBUF <device> <samples_count> <sample_size>\n"
		"\t\tRead raw data from the specified device\n");
		YYACCEPT;
	}
	| PRINT END {
		struct parser_pdata *pdata = yyget_extra(scanner);
		char *xml = iio_context_get_xml(pdata->ctx);
		if (!pdata->verbose)
			fprintf(pdata->out, "%lu\n", (unsigned long) strlen(xml));
		fprintf(pdata->out, "%s\n", xml);
		free(xml);
		YYACCEPT;
	}
	| READ SPACE WORD SPACE WORD END {
		char *id = $3, *attr = $5;
		struct parser_pdata *pdata = yyget_extra(scanner);
		ssize_t ret = read_dev_attr(pdata, id, attr);
		free(id);
		free(attr);
		if (ret < 0)
			YYABORT;
		else
			YYACCEPT;
	}
	| READBUF SPACE WORD SPACE WORD SPACE WORD END {
		char *id = $3, *attr = $5, *val = $7;
		unsigned long nb = atol(attr), samples_size = atol(val);
		struct parser_pdata *pdata = yyget_extra(scanner);
		ssize_t ret = read_dev(pdata, id, nb, samples_size);

		free(id);
		free(attr);
		free(val);
		if (ret < 0)
			YYABORT;
		else
			YYACCEPT;
	}
	| WRITE SPACE WORD SPACE WORD SPACE WORD END {
		char *id = $3, *attr = $5, *value = $7;
		struct parser_pdata *pdata = yyget_extra(scanner);
		ssize_t ret = write_dev_attr(pdata, id, attr, value);
		free(id);
		free(attr);
		free(value);
		if (ret < 0)
			YYABORT;
		else
			YYACCEPT;
	}
	| error END {
		yyclearin;
		yyerrok;
		YYACCEPT;
	}
	;

%%

void yyerror(yyscan_t scanner, const char *msg)
{
	struct parser_pdata *pdata = yyget_extra(scanner);
	fprintf(pdata->out, "Unable to perform operation: %s\n", msg);
}
