fun main() {
    val gateClass = try { Class.forName("com.csdcorp.speech_to_text.RecognitionSessionGate") }
    catch (_: ClassNotFoundException) { throw AssertionError("native session gate is missing") }
    val terminal = gateClass.methods.singleOrNull { it.name == "finishAfterForward" }
        ?: throw AssertionError("terminal event must be forwarded before acknowledgement")
    val gate = gateClass.getDeclaredConstructor().newInstance()
    val start = gateClass.getMethod("start")
    val current = gateClass.getMethod("isCurrent", java.lang.Long.TYPE)
    val currentGeneration = gateClass.getMethod("currentGeneration")
    val stop = gateClass.getMethod("requestStop", kotlin.jvm.functions.Function1::class.java)
    val finish = gateClass.getMethod("finish", java.lang.Long.TYPE)
    val fail = gateClass.getMethod("failStop")
    val first = start.invoke(gate) as Long
    check(currentGeneration.invoke(gate) == first)
    val acknowledgements = mutableListOf<Boolean>()
    val callback: (Boolean) -> Unit = { acknowledgements.add(it) }
    check(stop.invoke(gate, callback) == true)
    check(stop.invoke(gate, callback) == false)
    check(acknowledgements.isEmpty()) { "stop completed before a terminal callback" }
    check(start.invoke(gate) == null) { "start admitted during teardown" }
    finish.invoke(gate, first + 1)
    check(acknowledgements.isEmpty()) { "stale callback completed the stop" }
    val events = mutableListOf<String>()
    val forward: () -> Unit = { events.add("forward") }
    val orderingGate = gateClass.getDeclaredConstructor().newInstance()
    val orderingGeneration = start.invoke(orderingGate) as Long
    val orderedCallback: (Boolean) -> Unit = { events.add("ack") }
    stop.invoke(orderingGate, orderedCallback)
    val failedForward: () -> Unit = { throw IllegalStateException("delivery failed") }
    try {
        terminal.invoke(orderingGate, orderingGeneration, failedForward)
        error("forwarding failure was not propagated")
    } catch (_: java.lang.reflect.InvocationTargetException) { }
    check(events.isEmpty())
    check(start.invoke(orderingGate) == null)
    terminal.invoke(orderingGate, orderingGeneration, forward)
    check(events == listOf("forward", "ack"))
    finish.invoke(gate, first)
    check(currentGeneration.invoke(gate) == null)
    finish.invoke(gate, first)
    check(acknowledgements == listOf(true, true))
    val second = start.invoke(gate) as Long
    check(current.invoke(gate, first) == false)
    check(current.invoke(gate, second) == true)
    acknowledgements.clear()
    check(stop.invoke(gate, callback) == true)
    fail.invoke(gate)
    check(acknowledgements == listOf(false))
    check(start.invoke(gate) == null) { "failed stop must remain closed" }
    check(stop.invoke(gate, callback) == true) { "failed stop must be retryable" }
    finish.invoke(gate, second)
    check(acknowledgements == listOf(false, true))
    acknowledgements.clear()
    check(stop.invoke(gate, callback) == false)
    check(acknowledgements == listOf(true)) { "already terminal session must complete" }
}
