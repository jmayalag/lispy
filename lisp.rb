# An environment: a dict of {'var':val} pairs, with an outer Env.
class Env < Hash
  attr_reader :outer
  def initialize(parms=[], args=[], outer=nil)
    @outer = outer
    (parms.is_a? Array) ? update(Hash[parms.zip(args)]) : update(Hash[parms,args])
  end 
  
  # Find the innermost Env where var appears.
  def find(var)
    (include? var)? self : outer.find(var)
  end
  
end

# Add some Scheme standard procedures to an environment.
def add_globals(env)
  #env.update(vars(Math))
  operators = {
    :+ => lambda {|a,b| a+b},             :- => lambda {|a,b| a-b},
    :* => lambda {|a,b| a*b},             :/ => lambda {|a,b| a/b}, 
    :not => lambda {|a| !a},              :> => lambda {|a,b| a>b}, 
    :< => lambda {|a,b| a<b},             :>= => lambda {|a,b| a>=b},
    :<= => lambda {|a,b| a<=b},           :"=" => lambda {|a,b| a==b},
    :equal? => lambda {|a,b| a==b},       :eq? => lambda {|a,b| a.equal? b}, 
    :length => lambda {|a| a.length},     :cons => lambda {|x,y| [x]+y},
    :car => lambda {|x| x[0]},            :cdr => lambda {|x| x[1..-1]},
    :append => lambda {|x,y| x+y},        :list => lambda {|*x| x},
    :list? => lambda {|x| x.is_a? Array}, :null? => lambda {|x| x.nil?}, 
    :symbol? => lambda {|x| x.is_a? Symbol}
  }
  env.update(operators)
end

$global_env = add_globals(Env.new())
################ eval

# Evaluate an expression in an environment.
def eval(x, env=$global_env)
  # Corregir error para (literal) y (variable)
  x = x[0] if x.is_a? Array and x.length == 1 
  
  if x.is_a? Symbol                 # variable reference
    return env.find(x)[x]
  elsif  not x.is_a? Array         # constant literal
    return x    
  end
             
  case x[0]
  when :quote          # (quote exp)
    (_, exp) = x
    return exp
  when :if             # (if test conseq alt)
    (_, test, conseq, alt) = x
    return eval((eval(test, env) ? conseq : alt), env)
  when :set!           # (set! var exp)
    (_, var, exp) = x
    env.find(var)[var] = eval(exp, env)
  when :define         # (define var exp)
    (_, var, exp) = x
    env[var] = eval(exp, env)
  when :lambda         # (lambda (var*) exp)
    (_, vars, exp) = x
    return lambda {|*args| eval(exp, Env.new(vars, args, env))}
  when :begin          # (begin exp*)
    val = nil
    x.shift
    x.each {|expr| val = eval(expr,  env)}
    return val
  else                          # (proc exp*)
    exps = x.map {|expr| eval(expr, env)}
    proc = exps.shift
    return proc.call(*exps)
  end
end

################ parse, read, and user interaction

# Read a Scheme expression from a string.
def parse(s)
  return read_from(tokenize(s))
end

# Convert a string into a list of tokens.
def tokenize(s)
  return s.gsub('(', ' ( ').gsub(')', ' ) ').split
end

# Read an expression from a sequence of tokens.
def read_from(tokens)
  raise SyntaxError, 'unexpected EOF while reading' if tokens.length== 0
  token = tokens.shift #remove first element
  case token
  when '('
    l = []
    while tokens[0] != ')'
      l << read_from(tokens)
    end
    tokens.shift # pop off ')'
    return l
  when ')'
    raise SyntaxError, "unexpected ')'"
  else
    return atom(token)
  end
end

# Numbers become numbers; every other token is a symbol.
def atom(token)
  begin 
    return Integer(token)
  rescue TypeError, ArgumentError
    begin
      return Float(token)
    rescue TypeError, ArgumentError
      return token.to_sym
    end
  end
end

# Convert a Python object back into a Lisp-readable string.
def to_string(exp)
  return '(' + (exp.map {|x| to_string(x)}).join(' ') + ')' if exp.is_a? Array
  return String(exp) unless exp.is_a? Proc
end

# A prompt-read-eval-print loop.
def repl(prompt='lisp.rb> ')
  loop do
    print prompt
    val = eval(parse(gets.chomp))
    puts to_string(val) unless val.nil?
  end
end

def exec(p)
  puts ">> " + p
  val = eval(parse(p))
  puts to_string(val) unless val.nil?
end

repl()
exec("(define square (lambda (y) (* y y)))")
exec("(square 4)")
exec("( 12 )")
exec("(quote (a b c))")
exec("(if (< 10 20) (+ 1 1) (+ 3 3))")
exec("(define x 5)")
exec("(set! x 6)")
exec("( x )")
exec("(begin (define y 5) (+ y y))")
