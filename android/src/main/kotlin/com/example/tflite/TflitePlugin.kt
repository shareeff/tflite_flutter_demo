package com.example.tflite

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.BufferedReader
import java.io.FileInputStream
import java.io.IOException
import java.io.InputStreamReader
import java.lang.RuntimeException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

class TflitePlugin: MethodCallHandler {
  companion object {
    val TAG = "TensorflowLitePlugin"
    private var assetManager: AssetManager? = null
    private var registrar: Registrar? = null

    private var interpreter: Interpreter? = null
    private var inputSize: Int = 0
    private var labels: Vector<String> = Vector()
    var labelProb = arrayOf<Array<Float>>()
    private const val BYTES_PER_CHANNEL: Int = 4

    @JvmStatic
    fun registerWith(reg: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "tflite")
      channel.setMethodCallHandler(TflitePlugin())
      assetManager = reg.context().assets
      registrar = reg
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when(call.method){
      "getPlatformVersion" -> {
        try {
          val res = "Android ${android.os.Build.VERSION.RELEASE}"
          result.success(res)
        } catch (e: Exception) {
          result.error("Failed to get platform version", e.message, e)
        }
      }
      "loadModel" -> {
        try{
          val res = loadModel(call.arguments)
          result.success(res)

        }catch (e: Exception) {
          result.error("Failed to load model", e.message, e)
        }
      }
      "runModelOnImage" -> {
        try{
          runModelOnImage(call.arguments, result)

        }catch (e: Exception) {
          result.error("Failed to run Model on Image", e.message, e)
        }
      }
      "closeInterpreter" -> {
        try{
          closeInterpreter(result)
        }catch (e: Exception){
          result.error("Failed to close Interpreter", e.message, e)
        }
      }
      else -> result.notImplemented()

    }
  }

  @Throws(IOException::class)
  private fun loadModel(args: Any): String {
    val argsHashMap = args as HashMap<*, *>
    val model = argsHashMap["modelPath"].toString()
    val key = registrar!!.lookupKeyForAsset(model)
    val fileDescriptor = assetManager!!.openFd(key)
    val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
    val fileChannel = inputStream.channel
    val startOffset = fileDescriptor.startOffset
    val declaredLength = fileDescriptor.declaredLength
    val buffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)

    val numThreads = argsHashMap["numThreads"] as Int

    val interpreterOptions = Interpreter.Options()
    interpreterOptions.setNumThreads(numThreads)

    interpreter = Interpreter(buffer, interpreterOptions)

    val labelPath = argsHashMap["labelPath"].toString()
    loadLabels(labelPath)

    return "Success to load model"
  }

  private fun loadLabels(path: String){
    val br: BufferedReader
    val key = registrar!!.lookupKeyForAsset(path)
    try {
      br = BufferedReader(InputStreamReader(assetManager!!.open(key)))
      val lines: List<String> = br.readLines()
      lines.forEach{
        labels.add(it)
      }

      br.close()
    } catch (e: IOException){
      throw RuntimeException("Failed to read label file", e)
    }
  }

  @Throws(IOException::class)
  private fun feedInputTensor(bitmapRow: Bitmap, mean: Float, std: Float): ByteBuffer {
    val tensor = interpreter?.getInputTensor(0)
    val shape: IntArray? = tensor?.shape()
    inputSize = shape!![1]
    val inputChannel = shape[3]

    val bytePerChannel = if (tensor.dataType() == DataType.UINT8)  1 else BYTES_PER_CHANNEL
    val imgData: ByteBuffer = ByteBuffer.allocateDirect(1* inputSize * inputSize * inputChannel * bytePerChannel)
    imgData.order(ByteOrder.nativeOrder())
    val bitmap = Bitmap.createScaledBitmap(bitmapRow, inputSize, inputSize, true)

    if (tensor.dataType() == DataType.FLOAT32) {

      for (i in 0 until inputSize) {
        for (j in 0 until inputSize) {
          val pixelValue = bitmap.getPixel(j, i)
          imgData.putFloat(((pixelValue shr 16 and 0xFF) - mean) / std)
          imgData.putFloat(((pixelValue shr 8 and 0xFF) - mean) / std)
          imgData.putFloat(((pixelValue and 0xFF) - mean) / std)
        }
      }

    } else {
        for (i in 0 until inputSize){
          for (j in 0 until inputSize) {
            val pixelValue = bitmap.getPixel(j, i)
            imgData.put((pixelValue shr 16 and 0xFF).toByte())
            imgData.put((pixelValue shr 8 and 0xFF).toByte())
            imgData.put((pixelValue and 0xFF).toByte())
          }

        }
    }

    return imgData

  }

  @Throws(IOException::class)
  private fun feedInputTensorImage(path: String, mean: Float, std: Float): ByteBuffer {
    val inputStream = FileInputStream(path.replace("file://", ""))
    val bitmapRow = BitmapFactory.decodeStream(inputStream)

    return feedInputTensor(bitmapRow, mean, std)
  }

  private fun processOutput(numResults: Int, threshold: Float): List<Map<String, Any>> {

    val pq = PriorityQueue<Map<String, Any>>(
            1,
            Comparator { o1: Map<String, Any>, o2: Map<String, Any> ->
              (o1["confidence"] as Float).compareTo(o2["confidence"] as Float)
            }
    )
    labels.forEachIndexed{ index, label ->
      val confidence = labelProb[0][index]
      if(confidence > threshold){
        val res = HashMap<String, Any>()
        res["index"] = index
        res["label"] = if (labels.size > index) label else "Unknown"
        res["confidence"] = confidence
        pq.add(res)
      }

    }

    val recognitions = ArrayList<Map<String, Any>>()
    val recognitionsSize = Math.min(pq.size, numResults)
    for(i in 0 until recognitionsSize){
      recognitions.add(pq.poll())
    }

    return recognitions

  }

  @Throws(IOException::class)
  private fun runModelOnImage(args: Any, result: Result){

    if (interpreter == null){
      result.error("0", "Interpreter not created", "Interpreter not created")
      return
    }
    val argsHashMap = args as HashMap<*, *>
    val path = argsHashMap["imagePath"].toString()
    val mean = argsHashMap["imageMean"] as Double
    val imageMean = mean.toFloat()
    val std = argsHashMap["imageStd"] as Double
    val imageStd = std.toFloat()
    val numOfResults = argsHashMap["numResults"] as Int
    val threshold = argsHashMap["threshold"] as Double
    val resultThreshold = threshold.toFloat()
    val input = feedInputTensorImage(path, imageMean, imageStd)
    interpreter?.run(input, labelProb)

    result.success(processOutput(numOfResults, resultThreshold))

  }


  @Throws(IOException::class)
  private fun closeInterpreter(result: Result){
    interpreter?.close()
    interpreter = null
    result.success("Interpreter session closed.")

  }
}
