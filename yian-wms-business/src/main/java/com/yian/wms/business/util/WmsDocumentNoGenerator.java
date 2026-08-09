package com.yian.wms.business.util;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

/** 单据号生成器：时间戳 + 进程序列 + 随机数，降低多线程及多实例碰撞概率。 */
public final class WmsDocumentNoGenerator
{
    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private static final AtomicLong SEQUENCE = new AtomicLong();
    private static final SecureRandom RANDOM = new SecureRandom();

    private WmsDocumentNoGenerator() { }

    public static String next(String prefix)
    {
        long sequence = Math.floorMod(SEQUENCE.getAndIncrement(), 1296L);
        String random = Long.toUnsignedString(RANDOM.nextLong(), 36).toUpperCase(Locale.ROOT);
        return prefix + LocalDateTime.now().format(FORMATTER) + padBase36(sequence, 2) + "0".repeat(13 - random.length()) + random;
    }

    private static String padBase36(long value, int length)
    {
        String text = Long.toString(value, 36).toUpperCase();
        return "0".repeat(length - text.length()) + text;
    }
}
