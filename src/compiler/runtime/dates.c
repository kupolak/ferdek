/* ---- KALENDARZ: dni od 1970-01-01, ten sam algorytm co w interpreterze ---- */
static long long days_from_civil(long long y, long long m, long long d) {
    y -= m <= 2;
    long long era = (y >= 0 ? y : y - 399) / 400;
    long long yoe = y - era * 400;
    long long doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
    long long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}
static void civil_from_days(long long z, long long* y, long long* m, long long* d) {
    z += 719468;
    long long era = (z >= 0 ? z : z - 146096) / 146097;
    long long doe = z - era * 146097;
    long long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    long long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    long long mp = (5 * doy + 2) / 153;
    *d = doy - (153 * mp + 2) / 5 + 1;
    *m = mp < 10 ? mp + 3 : mp - 9;
    *y = yoe + era * 400 + (*m <= 2);
}
static int days_in_month(long long y, long long m) {
    if (m == 2) return ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 29 : 28;
    return (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31;
}
static long long parse_date(const char* what, FerdekValue v) {
    char* s = to_str(v);
    int ok = strlen(s) == 10 && s[4] == '-' && s[7] == '-';
    for (int i = 0; ok && i < 10; i++) if (i != 4 && i != 7 && (s[i] < '0' || s[i] > '9')) ok = 0;
    long long y = 0, m = 0, d = 0;
    if (ok) {
        y = (s[0] - '0') * 1000 + (s[1] - '0') * 100 + (s[2] - '0') * 10 + (s[3] - '0');
        m = (s[5] - '0') * 10 + (s[6] - '0');
        d = (s[8] - '0') * 10 + (s[9] - '0');
        ok = y >= 1 && m >= 1 && m <= 12 && d >= 1 && d <= days_in_month(y, m);
    }
    if (!ok) ferdek_die("%s: zła data \"%s\" (ma być RRRR-MM-DD)", what, s);
    fx_free(s);
    return days_from_civil(y, m, d);
}
static FerdekValue format_date(const char* what, long long z) {
    long long y, m, d;
    civil_from_days(z, &y, &m, &d);
    if (y < 1 || y > 9999) ferdek_die("%s: wynik poza latami 1-9999", what);
    char buf[16];
    snprintf(buf, sizeof buf, "%04lld-%02lld-%02lld", y, m, d);
    return make_string(buf);
}
static FerdekValue b_dzis(int argc, FerdekValue* argv) {
    time_t now = time(NULL); struct tm t; localtime_r(&now, &t);
    char buf[16]; snprintf(buf, sizeof buf, "%04d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
    return make_string(buf);
}
static FerdekValue b_godzina(int argc, FerdekValue* argv) {
    time_t now = time(NULL); struct tm t; localtime_r(&now, &t);
    char buf[16]; snprintf(buf, sizeof buf, "%02d:%02d:%02d", t.tm_hour, t.tm_min, t.tm_sec);
    return make_string(buf);
}
static FerdekValue b_dzien_tygodnia(int argc, FerdekValue* argv) {
    static const char* names[] = { "poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela" };
    long long z = parse_date("DZIEŃ TYGODNIA", argv[0]);
    return make_lit(names[((z % 7) + 7 + 3) % 7]);
}
static FerdekValue b_dodaj_dni(int argc, FerdekValue* argv) {
    return format_date("DODAJ DNI", iadd(parse_date("DODAJ DNI", argv[0]), to_int(argv[1])));
}
static FerdekValue b_ile_dni(int argc, FerdekValue* argv) {
    return make_int(parse_date("ILE DNI MIĘDZY", argv[1]) - parse_date("ILE DNI MIĘDZY", argv[0]));
}

