#General Util Functions
str=(obj)->
    if obj == null then "null"
    else if typeof obj == "undefined" then "undefined"
    else obj.toString()

#General Testing Code
class Test
    constructor:(@name, @func)->
        @num = 0
    expect:(num)->
        @num = num
    equal:(arg1, arg2, message="''")->
        @num--
        if arg1 != arg2 then throw "NotEqual: '#{str(arg1)}' does not equal '#{str(arg2)}'\n   #{message}"
    deepEqual:(arg1, arg2, message="")->
        @num--
        if not require('deep-equal')(arg1, arg2) then throw "NotEqual: '#{str(arg1)}' does not equal '#{str(arg2)}'\n   #{message}"
    ok:(bool,message="")->
        @num--
        if not bool then throw "NotOk: false was passed to ok\n   #{message}"
    done:(message="")->
        if @num != 0 then throw "NotDone: #{str(@num)} more checks were expected before done was called\n   #{message}"
    run:()->
        @func.call(this)
        @done()
        
test=(name, func)->
    t = new Test(name, func)
    exports[name]=()->t.run()

exports.RunAll = (throwException)->
    for name of exports
        if name != "RunAll"
            if throwException then exports[name]()
            else
                try
                    exports[name]()
                catch ex
                    console.log "Error in Test '#{name}'"
                    console.log "Message: #{ex}"
                    console.log "Stack:\n#{ex.stack}"
                    console.log ''
    return

#File specific test functions
unifylib=require("../lib/unify")
for prop of unifylib
    global[prop] = unifylib[prop]

class UnifyTest extends Test
    boxtest:(obj) ->
        @num++
        @deepEqual(box(obj).unbox(),obj, "box")
    unifytest:(obj1, obj2) -> 
        @num++
        obj1 = box(obj1)
        obj2 = box(obj2)
        @ok(obj1.unify(obj2), "unify")
    unifyfailtest:(obj1, obj2) ->
        @boxtest(obj1)
        @boxtest(obj2)
        @num++
        obj1 = box(obj1)
        obj2 = box(obj2)
        @ok(!obj1.unify(obj2), "unify fail")
    gettest:(tin, varValueDict) ->
        for v of varValueDict
            @num++
            if varValueDict[v] instanceof variable
                @ok(tin.get(v) instanceof variable, "get(#{ v }) = variable()")
            else
                @deepEqual(tin.get(v), varValueDict[v], "get(#{ v }) == #{ toJson varValueDict[v] }")
    fulltest:(obj1, obj2, varValueDict1, varValueDict2) ->
        @boxtest(obj1)
        @boxtest(obj2)
        obj1 = box(obj1)
        obj2 = box(obj2)
        @unifytest(obj1, obj2)
        @gettest(obj1, varValueDict1)
        @gettest(obj2, varValueDict2)

test=(name, func)->
    t = new UnifyTest(name, func)
    exports[name]=()->t.run()  
 
#######################
#full tests
#######################
test "empty obj {} -> {}", ()->
    @fulltest({}, {}, {}, {})
test "empty obj {test:'test', cool:1},{test:'test', cool:1}", ()->
    @fulltest({test:"test", cool:1},{test:"test", cool:1}, {}, {})
test "null test [null] -> [null]", ()->
    @fulltest([null], [null], {}, {})
test "variable equal [X] -> [1]", ()->
    @fulltest([variable("a")], [1], {a:1}, {})
test "variable equal [X,X] -> [1,1]", ()->
    @fulltest([variable("a"), variable("a")], [1,1], {a:1}, {})
test "variable equal [[1,2,3]] -> [y]", ()->
    @fulltest([[1,2,3]], [variable("y")], {}, {y:[1,2,3]})
test "variable equal [[1,2,x],x] -> [y,3]", ()->
    @fulltest(
        [[1,2,variable("x")],variable("x")],
        [variable("y"),3],
        {x:3}, {y:[1,2,3]})
test "unbound variable [y]->[x]", ()->
    @fulltest([variable("y")], [variable("x")], {y:variable("x")}, {x:variable("x")})
test "variable equal [1,X,X] -> [Z,Z,1]", () ->
    @fulltest([1, variable("X"), variable("X")], [variable("Z"), variable("Z"), 1], {X:1}, {Z:1})
#######################
# type checking tests
#######################
test "variable equal [X:isNum,X] -> [1,1]", ()->
    @fulltest([variable("a", types.isNum), variable("a")], [1,1], {a:1}, {})
test "variable equal [X:isNum,X] -> ['str','str']", ()->
    @unifyfailtest([variable("a", types.isNum), variable("a")], ['str','str'], {a:1}, {})
test "variable equal [X:isNum,X:isStr] -> ['str','str']", ()->
    threw = false
    try
        @fulltest([variable("a", types.isNum), variable("a", types.isStr)], ['str','str'], {a:1}, {})
    catch ex # a var defined with two diffrent types should blow up
        threw = true
    @ok(threw, "Variable defined with two diffrent types did not throw exception")
#######################
# unify fail tests
#######################
test "variable equal [X,X] -> [1,2]", ()->
    @unifyfailtest([variable("a"), variable("a")], [1,2])
test "variable unequal [1,3,2] -> [Y,Y,2]", () ->
    @unifyfailtest([1, 3, 2], [variable("y"), variable("y"), 2])
test "variable unequal [1,X,X] -> [Z,Z,3]", () ->
    @unifyfailtest([1, variable("X"), variable("X")], [variable("Z"), variable("Z"), 3])
#######################
#misc tests
#######################
test "simple black box unify test", () ->
    @expect(1)
    @ok(box({a: [1,2,3]}).unify({a: [1,variable("b"),3]}))
test "unbox bound variable", () ->
    @expect(2)
    i1 = box([1,variable("a")])
    i2 = box([1,1])
    @ok(i1.unify(i2))
    @deepEqual(i1.unbox(),i2.unbox())
#######################
#bind tests
#######################
test "bind test with no var", ()->
    @expect(1)
    i1 = box([1,variable("a")])
    i2 = {test:"test", fun:"somthing"}
    @deepEqual(i1.bind("a",i2)[0].get("a"),i2)
test "bind test with var", ()->
    @expect(1)
    i1 = box([1,variable("a")])
    i2 = [1,variable("b")]
    i3 = [1,[1,2]]
    @deepEqual(i1.bind("a",i2)[0].unify(i3)[0].unbox(), i3)
#######################
#unify tests
#######################
test "variable equal [X,2,X] -> [1,2,1]", () ->
    @expect(2)
    tins = box([variable("x"), 2, variable("x")]).unify([1,2,1])
    @ok(tins)
    @deepEqual(tins[0].getAll(), {"x":1})
#######################
#extract tests
#######################
test "simple variable extraction test", () ->
    @expect(1)
    tins = box({a: [1,2,3]}).unify({a: [1,variable("b"),3]})
    @ok(tins[1].get("b") == 2)
test "extract all variables test", () ->
    @expect(1)
    tins = box({a: [1,2,3]}).unify({a: [1,variable("b"),3]})
    @deepEqual(tins[1].getAll(), {"b":2})
#######################
#hidden variables tests
#######################
test "create hidden variable", () ->
    @expect(1)
    @ok((variable("_")).isHiddenVar())
test "simple hidden variable [_,X] -> [1,2]", () ->
    @fulltest([variable("_"),variable("x")],[1,2],{"x":2},{})
test "multiple hidden variables [_,_,X] -> [1,2,3]", () ->
    @fulltest([variable("_"),variable("_"),variable("x")],[1,2,3],{"x":3},{})
test "[[1,_,3],[1,2,3]] -> [X,X]", () ->
    @fulltest([[1,variable("_"),3],[1,2,3]],[variable("x"),variable("x")],{},{"x":[1,2,3]})
#######################
#rollback tests
#######################
test "rollback successful unification", () ->
    @expect(3)
    obj1 = [1,2,3]
    obj2 = [variable("A"), variable("B"), 3]
    @boxtest(obj1)
    @boxtest(obj2)
    obj1 = box(obj1)
    obj2 = box(obj2)
    cobj1 = eval(obj1.toString())
    cobj2 = eval(obj2.toString())
    @ok(obj1.unify(obj2), "unify")
    obj1.rollback()
    @ok( obj1.toString() == cobj1.toString() )
    @ok( obj2.toString() == cobj2.toString() )
