package com.lesgo.saar

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.LongBuffer
import kotlin.math.exp

class LocalNluEngine(modelPath: String) {
    private val env = OrtEnvironment.getEnvironment()
    private val session: OrtSession

    init {
        session = env.createSession(modelPath, OrtSession.SessionOptions())
    }

    fun parse(inputIds: LongArray, attentionMask: LongArray): FloatArray {
        val inputTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(inputIds), longArrayOf(1, inputIds.size.toLong()))
        val maskTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(attentionMask), longArrayOf(1, attentionMask.size.toLong()))
        
        val inputs = mapOf("input_ids" to inputTensor, "attention_mask" to maskTensor)
        val result = session.run(inputs)
        
        val logits = (result.get(0).value as Array<FloatArray>)[0]
        
        inputTensor.close()
        maskTensor.close()
        result.close()
        
        return softmax(logits)
    }

    private fun softmax(logits: FloatArray): FloatArray {
        val maxLogit = logits.maxOrNull() ?: 0f
        var sumExp = 0f
        val exps = FloatArray(logits.size)
        
        for (i in logits.indices) {
            exps[i] = exp(logits[i] - maxLogit)
            sumExp += exps[i]
        }
        
        for (i in exps.indices) {
            exps[i] /= sumExp
        }
        
        return exps
    }

    fun close() {
        session.close()
        env.close()
    }
}
