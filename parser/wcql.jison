/* description: Parses IBM Watson entities into a CQL string. */

/* declarations */

%{

    function stripQuotes(string) {
        return string.substring(1, string.length - 1);
    }

    function formatName(string) {
        return string.charAt(0).toUpperCase() + string.slice(1).replace(/(_\w)/g, function(m) {
            return m[1].toUpperCase();
        });
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

boolean_not:\S*                         return 'NOT';
boolean_and:\S*                         return 'AND';
boolean_or:\S*                          return 'OR';
number_criterion\b                      return 'NUMBERCRITERION';
'number_criterion_range:"less than"'    return 'NUMBERLT';
'number_criterion_range:"greater than"' return 'NUMBERGT';
'number_criterion_range:"between"'      return 'NUMBERBETWEEN';
'sys-number'                            return 'NUMBER';
[a-z_]+                                 return 'CRITERION';
':'                                     return 'COLON';
\"[^"\\]*(?:\\.[^"\\]*)*\"              return 'STRING';
\s+                                     /* skip whitespace */
<<EOF>>                                 return 'EOF';
.                                       return 'INVALID';

/lex

/* operator associations and precedence */

%left 'NOT'
%left 'AND'
%left 'OR'

%start expressions

%% /* language grammar */

expressions
    /* : NUMBERLT EOF */
    /*     { */
    /*         return 'lt'; */
    /*     } */
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
    : CRITERION COLON STRING
        {
            $$ = {};
            $$[formatName($1)] = $3;
        }
    | numberLessThan number
        {
            $$ = {};
            $$[$1] = '[0,' + $2 + ']';
        }
    | numberGreaterThan number
        {
            $$ = {};
            $$[$1] = '[' + $2 + ',0]';
        }
    | numberBetween rangeNumber
        {
            $$ = {};
            $$[$1] = $2;
        }
    ;

numberLessThan
    : numberCriterion NUMBERLT
        {
            $$ = $1;
        }
    | NUMBERLT numberCriterion
        {
            $$ = $2;
        }
    ;

numberGreaterThan
    : numberCriterion NUMBERGT
        {
            $$ = $1;
        }
    | NUMBERGT numberCriterion
        {
            $$ = $2;
        }
    ;

numberBetween
    : numberCriterion NUMBERBETWEEN
        {
            $$ = $1;
        }
    | NUMBERBETWEEN numberCriterion
        {
            $$ = $2;
        }
    ;

numberCriterion
    : NUMBERCRITERION COLON STRING
        {
            $$ = formatName(stripQuotes($3));
        }
    ;

rangeNumber
    : number number
        {
            $$ = '[' + $1 + ',' + $2 + ']';
        }
    | AND number number
        {
            $$ = '[' + $2 + ',' + $3 + ']';
        }
    ;

number
    : NUMBER COLON STRING
        {
            $$ = stripQuotes($3);
        }
    ;
