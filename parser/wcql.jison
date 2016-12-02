/* description: Parses IBM Watson entities into a CQL string. */

/* declarations */

%{

    function ucfirst(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

    function compose(query) {
        return subcompose(query);
    }

    function subcompose(query) {
        if (query.not) {
            var out = subcompose(query.not);
            if (query.not.sub) {
                out = '(' + out + ')';
            }
            return 'NOT ' + out;
        } else if (query.or) {
            var out = [];
            for (var i = 0; i < query.or.length; i++) {
                var sub = subcompose(query.or[i]);
                if (query.or[i].sub) {
                    sub = '(' + sub + ')';
                }
                out.push(sub);
            }
            return out.join(' OR ');
        } else if (query.and) {
            var out = [];
            for (var i = 0; i < query.and.length; i++) {
                var sub = subcompose(query.and[i]);
                if (query.and[i].sub) {
                    sub = '(' + sub + ')';
                }
                out.push(sub);
            }
            return out.join(' AND ');
        } else {
            var criteria = [];
            for (var c in query) {
                if (query.hasOwnProperty(c)) {
                    criteria.push(c + ' = ' + query[c]);
                }
            }
            return '(' + criteria.join(', ') + ')';
        }
    }

%}

/* lexical grammar */
%lex
%%

boolean_not:\S*             return 'NOT';
boolean_and:\S*             return 'AND';
boolean_or:\S*              return 'OR';
[a-z]+                      return 'NAME';
':'                         return 'COLON';
\"[^"\\]*(?:\\.[^"\\]*)*\"  return 'VALUE';
\s+                         /* skip whitespace */
<<EOF>>                     return 'EOF';
.                           return 'INVALID';

/lex

/* operator associations and precedence */

%left 'NOT'
%left 'AND'
%left 'OR'

%start expressions

%% /* language grammar */

expressions
    : query EOF
        {
            return compose($1);
        }
    ;

query
    : criterion
        {
            $$ = $1;
        }
    | orQuery
        {
            $$ = { 'or': $1, 'sub': true };
        }
    | andQuery
        {
            $$ = { 'and': $1, 'sub': true };
        }
    | NOT query
        {
            $$ = { 'not': $2 };
        }
    ;

orQuery
    : orQuery OR orQuery
        {
            $$ = $1.concat($3);
        }
    | orQuery OR query
        {
            $$ = $1.concat([ $3 ]);
        }
    | query OR orQuery
        {
            $$ = [ $1 ].concat($3);
        }
    | query OR query
        {
            $$ = [ $1 ].concat([ $3 ]);
        }
    ;

andQuery
    : andQuery AND andQuery
        {
            $$ = $1.concat($3);
        }
    | andQuery AND query
        {
            $$ = $1.concat([ $3 ]);
        }
    | query AND andQuery
        {
            $$ = [ $1 ].concat($3);
        }
    | query AND query
        {
            $$ = [ $1 ].concat([ $3 ]);
        }
    | andQuery andQuery
        {
            $$ = $1.concat($2);
        }
    | andQuery query
        {
            $$ = $1.concat([ $2 ]);
        }
    | query andQuery
        {
            $$ = [ $1 ].concat($2);
        }
    | query query
        {
            $$ = [ $1 ].concat([ $2 ]);
        }
    ;

criterion
    : NAME COLON VALUE
        {
            $$ = {};
            $$[ucfirst($1)] = $3;
        }
    ;
