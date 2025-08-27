package com.sharevideo.helpers

import androidx.media3.common.PlaybackException
import androidx.media3.datasource.HttpDataSource
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException

object RCTVideoErrorUtils {

    fun buildErrorCode(e: PlaybackException): String? {
        val cause = e.cause
        if (cause is HttpDataSource.InvalidResponseCodeException) {
            return "HTTP_${cause.responseCode}"
        }
        if (e.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED ||
                        e.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ||
                        isNetworkIssue(cause)
        ) {
            return "NETWORK"
        }
        if (cause is IOException) return "IO"
        return e.errorCodeName
    }

    fun buildErrorMessage(e: PlaybackException): String {
        val base = e.message ?: e.errorCodeName
        val cause = e.cause
        return if (cause is HttpDataSource.InvalidResponseCodeException) {
            "$base (HTTP ${cause.responseCode})"
        } else {
            base
        }
    }

    private fun isNetworkIssue(t: Throwable?): Boolean {
        var c = t
        while (c != null) {
            when (c) {
                is UnknownHostException,
                is SocketTimeoutException,
                is ConnectException,
                is SSLException -> return true
            }
            c = c.cause
        }
        return false
    }
}
