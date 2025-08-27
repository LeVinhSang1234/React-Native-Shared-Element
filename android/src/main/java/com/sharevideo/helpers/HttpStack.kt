package com.sharevideo.helpers

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import okhttp3.Cache
import okhttp3.CacheControl
import okhttp3.Dns
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.dnsoverhttps.DnsOverHttps
import okhttp3.logging.HttpLoggingInterceptor
import java.io.File
import java.net.InetAddress
import java.net.Proxy
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit

object HttpStack {
    data class Options(
        val cacheSizeBytes: Long = 4_000L * 1024 * 1024, // 4GB
//            val cacheSizeBytes: Long = -1L, // UN LIMIT
        val useDoh: Boolean = true, // bật DoH fallback
        val dohUrl: String = "https://1.1.1.1/dns-query", // Cloudflare DoH
        val dohBootstrap: List<InetAddress> =
                    listOf(InetAddress.getByName("1.1.1.1"), InetAddress.getByName("1.0.0.1")),
        val connectTimeoutSec: Long = 15,
        val readTimeoutSec: Long = 30,
        val proxy: Proxy? = null // nếu cần đặt proxy tay
    )

    @Volatile private var client: OkHttpClient? = null
    @Volatile private var lastOpts: Options? = null

    fun get(context: Context, opts: Options = Options()): OkHttpClient {
        client?.let { if (lastOpts == opts) return it }
        synchronized(this) {
            client?.let { if (lastOpts == opts) return it }
            val c = build(context.applicationContext, opts)
            client = c
            lastOpts = opts
            return c
        }
    }

    fun reset() {
        synchronized(this) {
            client = null
            lastOpts = null
        }
    }

    private fun build(ctx: Context, opts: Options): OkHttpClient {
        val cacheDir = File(ctx.cacheDir, "okhttp_http_cache").apply { mkdirs() }
        val maxSize = if (opts.cacheSizeBytes <= 0L) Long.MAX_VALUE else opts.cacheSizeBytes
        val cache = Cache(cacheDir, maxSize)

        val logger = HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BASIC }

        val builder =
                OkHttpClient.Builder()
                        .cache(cache)
                        .retryOnConnectionFailure(true)
                        .followRedirects(true)
                        .connectTimeout(opts.connectTimeoutSec, TimeUnit.SECONDS)
                        .readTimeout(opts.readTimeoutSec, TimeUnit.SECONDS)
                        .writeTimeout(opts.readTimeoutSec, TimeUnit.SECONDS)
                        .addInterceptor(offlineCacheInterceptor(ctx))
                        .addNetworkInterceptor(defaultCacheHeaderIfAbsent())
                        .addInterceptor(logger)

        opts.proxy?.let { builder.proxy(it) }

        if (opts.useDoh) {
            val bootstrap = OkHttpClient.Builder().connectTimeout(60, TimeUnit.SECONDS).build()
            val doh =
                    DnsOverHttps.Builder()
                            .client(bootstrap)
                            .url(opts.dohUrl.toHttpUrl())
                            .bootstrapDnsHosts(opts.dohBootstrap)
                            .build()
            builder.dns(SystemThenDohDns(doh))
        }

        return builder.build()
    }

    private class SystemThenDohDns(private val doh: Dns) : Dns {
        override fun lookup(hostname: String): List<InetAddress> {
            return try {
                Dns.Companion.SYSTEM.lookup(hostname)
            } catch (_: UnknownHostException) {
                doh.lookup(hostname)
            }
        }
    }

    private fun offlineCacheInterceptor(ctx: Context): Interceptor = Interceptor { chain ->
        var req = chain.request()
        if (!hasNetwork(ctx)) {
            req = req.newBuilder().cacheControl(CacheControl.Companion.FORCE_CACHE).build()
        }
        chain.proceed(req)
    }

    private fun defaultCacheHeaderIfAbsent(): Interceptor = Interceptor { chain ->
        val resp = chain.proceed(chain.request())
        val cc = resp.header("Cache-Control")
        if (cc.isNullOrBlank()) {
            resp.newBuilder().header("Cache-Control", "public, max-age=86400").build()
        } else resp
    }

    private fun hasNetwork(ctx: Context): Boolean {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = cm.activeNetwork ?: return false
        val cap = cm.getNetworkCapabilities(net) ?: return false
        return cap.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}