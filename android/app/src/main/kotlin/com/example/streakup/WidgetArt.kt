package com.example.streakup

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import kotlin.math.ceil
import kotlin.math.max

/** Draws the widget's artwork and text as bitmaps with bundled fonts. */
object WidgetArt {

    // Design canvas for the left panel (1 unit = 1 px)
    private const val W = 540
    private const val H = 500
    private const val FLAME_SCALE = 0.338f

    private val NAVY = 0xFF14143F.toInt()

    // ------------------------------------------------------------------ fonts
    private var hand: Typeface? = null
    private var note: Typeface? = null

    private fun handFont(ctx: Context): Typeface =
        hand ?: load(ctx, "fonts/patrick_hand.ttf").also { hand = it }

    private fun noteFont(ctx: Context): Typeface =
        note ?: load(ctx, "fonts/kalam.ttf").also { note = it }

    private fun load(ctx: Context, path: String): Typeface =
        try {
            Typeface.createFromAsset(ctx.assets, path)
        } catch (e: Exception) {
            Typeface.DEFAULT
        }

    // ------------------------------------------------------------------ flame paths
    private const val FLAME_OUT =
        "M400 832 C382 831 327 834 290 826 C253 818 213 805 180 785 C147 765 114 734 92 705 C70 676 57 639 48 610 C39 581 34 559 38 530 C42 501 66 452 72 437 C75 443 83 462 92 472 C101 482 120 492 126 496 C124 483 114 447 114 420 C114 393 122 357 128 335 C134 313 143 299 150 288 C157 277 168 271 172 268 C178 275 194 300 205 312 C216 324 228 335 238 342 C248 349 261 350 266 352 C264 343 254 320 254 300 C254 280 258 252 264 232 C270 212 281 192 290 178 C299 164 313 150 318 145 C320 150 328 168 332 178 C336 188 340 197 343 205 C346 213 350 224 352 228 C354 215 361 175 366 150 C371 125 376 99 380 80 C384 61 390 42 392 34 C402 38 431 41 450 55 C469 69 491 94 505 120 C519 146 526 182 532 210 C538 238 540 267 540 290 C540 313 533 340 532 350 C537 349 554 350 562 342 C570 334 576 313 582 300 C588 287 597 268 600 262 C605 269 623 285 632 305 C641 325 650 356 655 380 C660 404 665 432 664 450 C663 468 652 483 650 490 C654 489 665 490 672 484 C679 478 684 465 690 455 C696 445 703 429 706 424 C710 434 725 462 732 485 C739 508 747 537 746 565 C745 593 739 627 728 655 C717 683 701 712 678 735 C655 758 621 777 590 792 C559 807 522 817 490 824 C458 831 415 831 400 832 Z"

    private const val FLAME_MID =
        "M400 845 C373 840 285 837 240 815 C195 793 151 751 130 715 C109 679 113 635 112 600 C111 565 116 532 122 505 C128 478 137 459 146 440 C155 421 173 400 178 392 C182 398 197 420 205 430 C213 440 222 451 225 455 C223 446 213 419 215 400 C217 381 225 357 235 340 C245 323 262 311 275 300 C288 289 304 279 310 275 C315 278 331 286 340 290 C349 294 361 298 365 300 C368 292 378 264 385 250 C392 236 397 226 405 215 C413 204 428 188 432 182 C438 192 460 220 470 240 C480 260 488 280 490 300 C492 320 482 350 480 360 C490 363 522 374 540 380 C558 386 574 393 585 395 C596 397 601 392 604 392 C611 400 636 417 644 440 C652 463 651 503 652 530 C653 557 656 571 652 600 C648 629 647 672 630 705 C613 738 588 772 550 795 C512 818 425 837 400 845 Z"

    private const val FLAME_CREAM =
        "M400 850 C375 838 285 807 250 780 C215 753 200 717 190 690 C180 663 185 645 188 620 C191 595 202 566 210 540 C218 514 231 478 235 465 C243 469 268 485 285 490 C302 495 327 494 335 495 C338 482 347 440 355 420 C363 400 377 388 385 375 C393 362 402 350 405 345 C409 351 422 366 430 380 C438 394 448 412 455 430 C462 448 468 480 470 490 C477 490 501 492 510 490 C519 488 520 484 525 480 C530 476 539 470 542 468 C548 480 565 518 575 540 C585 562 598 577 600 600 C602 623 600 652 590 680 C580 708 572 742 540 770 C508 798 423 837 400 850 Z"

    private val outline: Path by lazy { parsePath(FLAME_OUT) }
    private val mid: Path by lazy { parsePath(FLAME_MID) }
    private val cream: Path by lazy { parsePath(FLAME_CREAM) }

    private fun parsePath(d: String): Path {
        val t = Regex("[MCZ]|-?\\d+(?:\\.\\d+)?").findAll(d).map { it.value }.toList()
        val p = Path()
        var i = 0
        while (i < t.size) {
            when (t[i]) {
                "M" -> {
                    p.moveTo(t[i + 1].toFloat(), t[i + 2].toFloat())
                    i += 3
                }
                "C" -> {
                    p.cubicTo(
                        t[i + 1].toFloat(), t[i + 2].toFloat(),
                        t[i + 3].toFloat(), t[i + 4].toFloat(),
                        t[i + 5].toFloat(), t[i + 6].toFloat()
                    )
                    i += 7
                }
                "Z" -> {
                    p.close()
                    i += 1
                }
                else -> i += 1
            }
        }
        return p
    }

    private fun drawFlame(c: Canvas) {
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)

        fill.shader = RadialGradient(
            390f, 700f, 470f,
            intArrayOf(0xFFFF9A45.toInt(), 0xFFFF7440.toInt(), 0xFFEE3A30.toInt()),
            floatArrayOf(0f, 0.45f, 1f), Shader.TileMode.CLAMP
        )
        c.drawPath(outline, fill)

        c.save()
        c.clipPath(outline)
        fill.shader = LinearGradient(
            0f, 180f, 0f, 845f,
            0xFFFF9B47.toInt(), 0xFFFFCB6B.toInt(), Shader.TileMode.CLAMP
        )
        c.drawPath(mid, fill)
        fill.shader = RadialGradient(
            392f, 648f, 290f,
            0xFFFFF7DA.toInt(), 0xFFFFE39A.toInt(), Shader.TileMode.CLAMP
        )
        c.drawPath(cream, fill)
        c.restore()

        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 13f
            strokeJoin = Paint.Join.ROUND
            color = 0xFF9A1E3C.toInt()
        }
        c.drawPath(outline, stroke)
    }

    // ------------------------------------------------------------------ helpers
    private fun fitWidth(p: Paint, text: String, target: Float) {
        p.textSize = 100f
        p.textSize = 100f * target / p.measureText(text)
    }

    private fun drawCentered(c: Canvas, text: String, cx: Float, cy: Float, p: Paint) {
        val b = Rect()
        p.getTextBounds(text, 0, text.length, b)
        c.drawText(text, cx - (b.left + b.right) / 2f, cy - (b.top + b.bottom) / 2f, p)
    }

    // ------------------------------------------------------------------ left panel
    /** Title + flame with streak number + "Keep going!" note + "day streak" pill. */
    fun leftPanel(ctx: Context, streak: Int): Bitmap {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val hand = handFont(ctx)
        val note = noteFont(ctx)

        // Title
        val title = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = hand; color = NAVY; isFakeBoldText = true
        }
        fitWidth(title, "StreakUp", 362f)
        c.drawText("StreakUp", 48f, 92f, title)

        // Flame
        c.save()
        c.translate(100f - 36f * FLAME_SCALE, 140f - 34f * FLAME_SCALE)
        c.scale(FLAME_SCALE, FLAME_SCALE)
        drawFlame(c)
        c.restore()

        // Streak number inside the flame (shrinks for long numbers)
        val num = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = hand; color = NAVY; isFakeBoldText = true; textSize = 84f
        }
        val s = streak.toString()
        val b = Rect()
        num.getTextBounds(s, 0, s.length, b)
        num.textSize = 84f * 60f / max(1, b.height())
        num.getTextBounds(s, 0, s.length, b)
        if (b.width() > 140) num.textSize = num.textSize * 140f / b.width()
        drawCentered(c, s, 220f, 342f, num)

        // "day streak" pill
        val pill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFE4E2FA.toInt() }
        c.drawRoundRect(RectF(62f, 408f, 384f, 490f), 41f, 41f, pill)
        val pillText = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = hand; color = 0xFF5B52E8.toInt()
        }
        fitWidth(pillText, "day streak", 196f)
        drawCentered(c, "day streak", 223f, 449f, pillText)

        // "Keep going!" note, tilted, with squiggle
        c.save()
        c.rotate(-14f, 452f, 230f)
        val np = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = note; color = 0xFF7B82C4.toInt()
        }
        fitWidth(np, "going!", 150f)
        c.drawText("Keep", 452f - np.measureText("Keep") / 2f, 220f, np)
        c.drawText("going!", 452f - np.measureText("going!") / 2f, 274f, np)
        val sq = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 4f
            strokeCap = Paint.Cap.ROUND
            color = 0xFF7B82C4.toInt()
        }
        c.drawPath(Path().apply { moveTo(420f, 303f); quadTo(445f, 293f, 500f, 296f) }, sq)
        c.drawPath(Path().apply { moveTo(440f, 315f); quadTo(462f, 306f, 488f, 309f) }, sq)
        c.restore()

        return bmp
    }

    // ------------------------------------------------------------------ plain text
    /** Single line of text in the Patrick Hand font, sized in dp. */
    fun textBitmap(
        ctx: Context,
        text: String,
        sizeDp: Float,
        color: Int,
        maxWidthDp: Float = 0f,
        bold: Boolean = false
    ): Bitmap {
        val density = ctx.resources.displayMetrics.density
        val p = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = handFont(ctx)
            textSize = sizeDp * density
            this.color = color
            isFakeBoldText = bold
        }
        var shown: CharSequence = text
        if (maxWidthDp > 0f) {
            shown = TextUtils.ellipsize(text, p, maxWidthDp * density, TextUtils.TruncateAt.END)
        }
        val fm = p.fontMetrics
        val w = max(1, ceil(p.measureText(shown, 0, shown.length)).toInt() + 2)
        val h = max(1, ceil(fm.descent - fm.ascent).toInt() + 2)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        Canvas(bmp).drawText(shown, 0, shown.length, 1f, 1f - fm.ascent, p)
        return bmp
    }
}