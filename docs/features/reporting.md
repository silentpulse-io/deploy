# Reporting

Generowanie raportów z danymi o widoczności bezpieczeństwa.
Raporty są narzędziem dla managementu — KPI, compliance, trend analysis.

## Typy raportów

### Pokrycie assetów

Stan widoczności per grupa assetów, region, criticality.

Przykład KPI: "Pokrycie assetów z criticality > 3 wynosi 94%"
— oznacza, że 94% krytycznych assetów raportuje w zdefiniowanych oknach czasowych.

### Przestoje widoczności

Historia przestojów — kiedy, jak długo, które grupy, jaki impakt MITRE.
Timeline z możliwością drill-down.

### Pokrycie MITRE ATT&CK

Ile technik MITRE jest pokrytych aktywnym monitorowaniem vs ile jest zagrożonych.
Trend w czasie — czy pokrycie rośnie czy maleje.

### Trend widoczności

Widoczność organizacji w czasie — zagregowane metryki:
- % assetów raportujących w oknie
- Średni czas przestoju
- Liczba alertów per okres

## Definicja raportu

Użytkownik (Admin/Analyst) tworzy definicję raportu:

- Nazwa
- Typ raportu
- Filtry (region, criticality, grupa assetów itd.)
- Okres (ostatnie 7 dni, miesiąc, kwartał, custom)
- Harmonogram generowania (daily, weekly, monthly)
- Sposób dostarczenia: email (lista odbiorców)
- Format: PDF, CSV

## Przykłady

```
Raport: "Weekly Asia Critical Assets Coverage"
  Typ:          Pokrycie assetów
  Filtry:       region IN (Singapore, Tokyo), criticality > 3
  Okres:        ostatnie 7 dni
  Harmonogram:  co poniedziałek 08:00
  Dostarczenie: email → ciso@company.com, security-mgmt@company.com
  Format:       PDF
```

```
Raport: "Monthly MITRE Coverage Trend"
  Typ:          Pokrycie MITRE ATT&CK
  Filtry:       brak (cała organizacja)
  Okres:        ostatni miesiąc
  Harmonogram:  1. dzień miesiąca
  Dostarczenie: email → board-security@company.com
  Format:       PDF
```

## Raporty ad-hoc

Oprócz raportów schedulowanych, użytkownik może wygenerować raport
na żądanie z dowolnymi filtrami i okresem.
