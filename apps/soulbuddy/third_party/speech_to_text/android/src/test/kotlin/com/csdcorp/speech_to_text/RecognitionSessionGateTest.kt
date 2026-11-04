package com.csdcorp.speech_to_text

import org.junit.Assert.*
import org.junit.Test

class RecognitionSessionGateTest {
    @Test fun waitsForTerminalAndCompletesAllWaitersAfterForwarding() {
        val gate = RecognitionSessionGate()
        val generation = gate.start()!!
        val events = mutableListOf<String>()
        assertTrue(gate.requestStop { events.add("first:$it") })
        assertFalse(gate.requestStop { events.add("second:$it") })
        assertNull(gate.start())
        gate.finishAfterForward(generation + 1) { events.add("stale") }
        assertTrue(events.isEmpty())
        gate.finishAfterForward(generation) { events.add("forward") }
        assertEquals(listOf("forward", "first:true", "second:true"), events)
        assertNotNull(gate.start())
        assertFalse(gate.isCurrent(generation))
    }

    @Test fun forwardingFailureAndCommandFailureRemainClosedAndRetryable() {
        val gate = RecognitionSessionGate()
        val generation = gate.start()!!
        val events = mutableListOf<Boolean>()
        assertTrue(gate.requestStop { events.add(it) })
        try {
            gate.finishAfterForward(generation) { throw IllegalStateException() }
            fail("forwarding failure must propagate")
        } catch (_: IllegalStateException) { }
        assertTrue(events.isEmpty())
        assertNull(gate.start())
        gate.failStop()
        assertEquals(listOf(false), events)
        assertNull(gate.start())
        assertTrue(gate.requestStop { events.add(it) })
        gate.finishAfterForward(generation) { }
        assertEquals(listOf(false, true), events)
    }

    @Test fun alreadyTerminatedSessionAcknowledgesWithoutIssuingCommand() {
        val gate = RecognitionSessionGate()
        val generation = gate.start()!!
        gate.finishAfterForward(generation) { }
        val acknowledgements = mutableListOf<Boolean>()
        assertFalse(gate.requestStop { acknowledgements.add(it) })
        assertEquals(listOf(true), acknowledgements)
    }
    @Test fun onDeviceSelectionNeverFallsBackToDefaultRecognizer() {
        val policy = try { Class.forName("com.csdcorp.speech_to_text.RecognitionStartPolicy") }
            catch (_: ClassNotFoundException) { throw AssertionError("on-device policy missing") }
        val select = policy.getMethod("select", Boolean::class.javaPrimitiveType,
            Int::class.javaPrimitiveType, Boolean::class.javaPrimitiveType)
        val instance = policy.getField("INSTANCE").get(null)
        assertEquals("unavailable", select.invoke(instance, true, 29, false))
        assertEquals("unavailable", select.invoke(instance, true, 31, false))
        assertEquals("onDevice", select.invoke(instance, true, 31, true))
        assertEquals("default", select.invoke(instance, false, 29, false))
    }

    @Test fun cancelSuppressesResultsUntilTerminalCompletion() {
        val gate = RecognitionSessionGate()
        val cancel = gate.javaClass.methods.singleOrNull { it.name == "suppressResults" }
            ?: throw AssertionError("cancel suppression missing")
        val suppressed = gate.javaClass.methods.singleOrNull { it.name == "resultsSuppressed" }
            ?: throw AssertionError("cancel suppression query missing")
        val generation = gate.start()!!
        cancel.invoke(gate, generation)
        assertEquals(true, suppressed.invoke(gate, generation))
        gate.finishAfterForward(generation) { }
        val next = gate.start()!!
        assertEquals(false, suppressed.invoke(gate, next))
    }
    @Test fun startupReportsOnlyAfterBeginAndDistinguishesUncertainFailure() {
        val policy = try { Class.forName("com.csdcorp.speech_to_text.RecognitionStartPolicy") }
            catch (_: ClassNotFoundException) { throw AssertionError("startup policy missing") }
        val run = policy.getMethod("run", kotlin.jvm.functions.Function0::class.java,
            kotlin.jvm.functions.Function0::class.java)
        val instance = policy.getField("INSTANCE").get(null)
        val events = mutableListOf<String>()
        val prepare: () -> Unit = { events.add("prepare") }
        val begin: () -> Unit = { events.add("begin") }
        assertEquals("started", run.invoke(instance, prepare, begin))
        assertEquals(listOf("prepare", "begin"), events)
        val failure: () -> Unit = { throw IllegalStateException() }
        assertEquals("beforeStart", run.invoke(instance, failure, begin))
        assertEquals("afterStart", run.invoke(instance, prepare, failure))
    }
}
