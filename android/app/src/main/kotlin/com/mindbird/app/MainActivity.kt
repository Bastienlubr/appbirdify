package com.mindbird.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryPurchasesParams

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.mindbird.billing"
    private var billingClient: BillingClient? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "fetchActiveSubs" -> fetchActiveSubs(result)
                else -> result.notImplemented()
            }
        }

        billingClient = BillingClient.newBuilder(this)
            .enablePendingPurchases()
            .setListener(PurchasesUpdatedListener { _: BillingResult, _: MutableList<Purchase>? -> })
            .build()

        connectBilling { /* ready */ }
    }

    private fun connectBilling(onReady: () -> Unit) {
        val client = billingClient ?: return
        if (client.isReady) { onReady(); return }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingServiceDisconnected() { /* retry on demand */ }
            override fun onBillingSetupFinished(br: BillingResult) {
                if (br.responseCode == BillingClient.BillingResponseCode.OK) onReady()
            }
        })
    }

    private fun fetchActiveSubs(result: MethodChannel.Result) {
        connectBilling {
            val params = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
            billingClient?.queryPurchasesAsync(params) { br, list ->
                if (br.responseCode != BillingClient.BillingResponseCode.OK) {
                    result.error("BILLING_ERROR", br.debugMessage, null); return@queryPurchasesAsync
                }
                val mapped = list.map { p ->
                    mapOf(
                        "purchaseToken" to p.purchaseToken,
                        "products" to p.products,
                        "acknowledged" to p.isAcknowledged,
                        "autoRenewing" to p.isAutoRenewing
                    )
                }
                result.success(mapped)
            }
        }
    }
}



