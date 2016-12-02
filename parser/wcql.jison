/* description: Parses IBM Watson entities into a CQL string. */

/* declarations */

%{

    //js

    //

%}

/* lexical grammar */
%lex
%%

boolean_not:\S*             return 'NOT';
/* boolean_and:\S*             return 'AND'; */
/* boolean_or:\S*              return 'OR'; */
/* [a-zA-Z]+:                  return 'NAME'; */
/* \"[^"\\]*(?:\\.[^"\\]*)*\"  return 'STRING'; */
\S+
\s+                         /* skip whitespace */
<<EOF>>                     return 'EOF';
.                           return 'INVALID';

/lex

/* operator associations and precedence */

%left ','
%left 'OR'
%left 'AND'
%left 'NOT'

%start expressions

%% /* language grammar */

expressions
    : query EOF
        {
            return $1;
        }
    ;

query
    : NOT
        {
            $$ = 'not';
        }
    /* : criterion */
    /*     { */
    /*         $$ = $1; */
    /*     } */
    /* | andQuery */
    /*     { */
    /*         $$ = '(' + $1.join(' AND ') + ')'; */
    /*     } */
    /* | orQuery */
    /*     { */
    /*         $$ = '(' + $1.join(' OR ') + ')'; */
    /*     } */
    /* | NOT query */
    /*     { */
    /*         $$ = 'NOT (' + $1 + ')'; */
    /*     } */
    ;

/* orQuery */
/*     : orQuery OR orQuery */
/*         { */
/*             $$ = $1.concat($3); */
/*         } */
/*     | query OR orQuery */
/*         { */
/*             $$ = [ $1 ].concat($3); */
/*         } */
/*     | orQuery OR query */
/*         { */
/*             $$ = $1.concat([ $3 ]); */
/*         } */
/*     | query OR query */
/*         { */
/*             $$ = [ $1, $3 ]; */
/*         } */
/*     ; */

/* andQuery */
/*     : andQuery AND andQuery */
/*         { */
/*             $$ = $1.concat($3); */
/*         } */
/*     | query AND andQuery */
/*         { */
/*             $$ = [ $1 ].concat($3); */
/*         } */
/*     | andQuery AND query */
/*         { */
/*             $$ = $1.concat([ $3 ]); */
/*         } */
/*     | query AND query */
/*         { */
/*             $$ = [ $1, $3 ]; */
/*         } */
/*     ; */

/* criterion */
/*     : NAME VALUE */
/*         { */
/*             $$ = '(' + $1 + ' = "' + $2 + '")'; */
/*         } */
/*     ; */
