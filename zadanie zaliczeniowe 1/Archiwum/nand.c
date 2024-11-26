#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "nand.h"

typedef struct nand nand_t;

struct wejscia {  // Jest to struktura trzymająca informacje o wejściach bramki.
    void *wchodzace; /* Jest to zmienna, trzymająca wskaźnik na bramkę, która
                        jest podłączona do danego wejścia. */
    int sygnal; /* Jest to zmienna, trzymająca informację o sygnale, jaki jest
                   podłączony do danego wejścia. Sygnał ma wartość -1, gdy go
                   nie ma, 0 dla false i 1 dl true. */
    bool czy_bramka; /* Jest to zmienna, trzymająca informację o tym, czy do
                        danego wejścia jest podłączona inna bramka, czy sygnał
                        boolowski. */
    bool odwiedzone; /* Jest to zmienna przydatna w funkcji nand_evaluate do
                        wykrywania cykli. */
};
typedef struct wejscia Wejscia;

struct wyjscia { /* Jest to struktura, która stanowi wyjście danej bramki oraz
                    trzymająca informacje o wejściach, do których bramka jest
                    podłączona. */
    nand_t *wychodzace; /* Jest to zmienna, trzymająca wskaźnik na bramkę, do
                           której podłączona jest bramka. */
    unsigned numer; /* Jest to zmienna trzymająca informacje o numerze wejścia,
                       do którego jest podłączone wyjście bramki. */
    struct wyjscia *nast;
};
typedef struct wyjscia Wyjscia;

struct nand {
    unsigned ile_wejsc; /* Jest to zmienna, trzymająca informację o liczbie
                           wejść danej bramki. */
    int sygnal; /* Jest to zmienna trzymająca informację o sygnale, jaki bramka
                   oddaje. Sygnał ma wartość -1, gdy go nie ma, 0 dla false i 1
                   dl true.*/
    Wejscia *tablica;  // Jest to tablica wejść.
    Wyjscia *lista;    // Jest to lista wyjściowa.
};

nand_t *nand_new(unsigned n) {
    if (n > 0) {
        Wejscia *nowa = malloc(n * sizeof(Wejscia));
        if (nowa == NULL) {
            free(nowa);
            errno = ENOMEM;
            return NULL;
        }

        for (unsigned int i = 0; i < n; i++) {
            nowa[i].wchodzace = NULL;
            nowa[i].sygnal = -1; /* Ustawiam sygnal na -1, ponieważ jeszcze nic
                                    nie jest do tego wejścia podłączone. */
            nowa[i].czy_bramka = false;
            nowa[i].odwiedzone = false;
        }

        nand_t *Bramka = malloc(sizeof(nand_t));
        if (Bramka == NULL) {
            free(nowa);
            free(Bramka);
            errno = ENOMEM;
            return NULL;
        }

        Bramka->ile_wejsc = n;
        Bramka->sygnal = -1; /* Ponownie ustawiam sygnal na -1, ponieważ bramka
                                nie oddaje jeszcze żadnego sygnału. */
        Bramka->tablica = nowa;
        Bramka->lista = NULL;

        return Bramka;
    }

    if (n == 0) {
        nand_t *Bramka = malloc(sizeof(nand_t));
        if (Bramka == NULL) {
            free(Bramka);
            errno = ENOMEM;
            return NULL;
        }

        Bramka->ile_wejsc = 0;
        Bramka->sygnal = -1;
        Bramka->tablica = NULL; /* Tablica jest NULLem, ponieważ bramka nie ma
                                żadnych wejść i to się już nie zmieni. */
        Bramka->lista = NULL;
        return Bramka;
    }

    return NULL;
}

void nand_delete(nand_t *g) {
    if (g != NULL) {
        for (unsigned int i = 0; i < (g->ile_wejsc); i++) {
            /* Sprawdzam, czy do danego wejścia jest podłączona bramka, ponieważ
            jeśli tak, to trzeba usunąć usuwaną bramkę z jej listy
            wyjściowej.*/
            if (g->tablica[i].czy_bramka == true) {
                nand_t *pom = g->tablica[i].wchodzace;
                if (pom != NULL) {
                    Wyjscia **l = &(pom->lista);
                    Wyjscia *atrapa = *l;
                    Wyjscia *pop = atrapa;
                    Wyjscia *akt = *l;
                    if (akt->numer == i) {
                        akt = akt->nast;
                        free(pop);
                        atrapa = akt;
                        pom->lista = atrapa;
                    } 
                    else {
                        akt = akt->nast;
                        Wyjscia *next = NULL;
                        while (akt != NULL && akt->numer != i) {
                            pop = akt;
                            akt = akt->nast;
                        }
                        next = akt->nast;
                        pop->nast = next;
                        free(akt);
                        pom->lista = atrapa;
                    }
                }
            }

            g->tablica[i].wchodzace = NULL;
            g->tablica[i].sygnal = -1;
            g->tablica[i].czy_bramka = false;
        }

        free(g->tablica);

        /* Usuwanie listy wyjściowej oraz usuwanie występowań usuwanej bramki w
        wejściach bramek, do których była podłączona. */
        if (g->lista != NULL) {
            Wyjscia *pomoc = (g->lista);
            while (pomoc != NULL) {
                nand_t *pom1 = (g->lista)->wychodzace;
                unsigned int pom2 = (g->lista)->numer;
                pom1->tablica[pom2].wchodzace = NULL;
                pom1->tablica[pom2].sygnal = -1;
                pom1->tablica[pom2].czy_bramka = false;
                pomoc = pomoc->nast;
                free(g->lista);
                (g->lista) = pomoc;
            }
        }
        free(g);
    }
    return;
}

int nand_connect_nand(nand_t *g_out, nand_t *g_in, unsigned k) {
    if (g_out == NULL || g_in == NULL || k >= g_in->ile_wejsc) {
        errno = EINVAL;
        return -1;
    } 
    else {
        // Dodawanie do listy wyjściowej bramki g_out bramkę g_in.
        Wyjscia *pomoc = malloc(sizeof(Wyjscia));
        if (pomoc == NULL) {
            free(pomoc);
            errno = ENOMEM;
            return -1;
        } 
        else {
            pomoc->numer = k;
            pomoc->wychodzace = g_in;
            pomoc->nast = NULL;
            if (g_out->lista == NULL) {
                g_out->lista = pomoc;
            } 
            else {
                Wyjscia *pop = g_out->lista;
                Wyjscia *akt = pop->nast;
                while (akt != NULL) {
                    pop = pop->nast;
                    akt = akt->nast;
                }
                pop->nast = pomoc;
            }
        }

        /* Dodawanie do tablicy wejść bramki g_in bramkę g_out oraz usuwanie.
        ewentualnie podłaczonej wcześniej bramki. */
        if (g_in->tablica[k].czy_bramka != false &&
            g_in->tablica[k].wchodzace != NULL) {
            nand_t *pom = g_in->tablica[k].wchodzace;
            Wyjscia **l = &(pom->lista);
            Wyjscia *atrapa = malloc(sizeof(Wyjscia));
            if (atrapa == NULL) {
                free(atrapa);
                errno = ENOMEM;
                return -1;
            }
            atrapa->nast = *l;
            Wyjscia *pop = atrapa;
            Wyjscia *akt = *l;
            Wyjscia *nast = NULL;
            while (akt->numer != k) {
                pop = akt;
                akt = akt->nast;
            }
            nast = akt->nast;
            pop->nast = nast;
            free(akt);
            pom->lista = atrapa->nast;
            free(atrapa);
        }

        g_in->tablica[k].wchodzace = g_out;
        g_in->tablica[k].sygnal = g_out->sygnal;
        g_in->tablica[k].czy_bramka = true;

        return 0;
    }
}

int nand_connect_signal(bool const *s, nand_t *g, unsigned k) {
    if (s == NULL || g == NULL || k >= g->ile_wejsc) {
        errno = EINVAL;
        return -1;
    }
    if (g->tablica[k].wchodzace != NULL) {
        if (g->tablica[k].czy_bramka != false &&
            g->tablica[k].wchodzace != NULL) {
            nand_t *pom = g->tablica[k].wchodzace;
            Wyjscia **l = &(pom->lista);
            Wyjscia *atrapa = malloc(sizeof(Wyjscia));
            if (atrapa == NULL) {
                free(atrapa);
                errno = ENOMEM;
                return -1;
            }
            atrapa->nast = *l;
            Wyjscia *pop = atrapa;
            Wyjscia *akt = *l;
            Wyjscia *nast = NULL;
            while (akt->numer != k) {
                pop = akt;
                akt = akt->nast;
            }
            nast = akt->nast;
            pop->nast = nast;
            free(akt);
            pom->lista = atrapa->nast;
            free(atrapa);
        }
    }
    g->tablica[k].wchodzace = (bool *)s;
    if (*s == false) {
        g->tablica[k].sygnal = 0;
    } 
    else {
        g->tablica[k].sygnal = 1;
    }

    g->tablica[k].czy_bramka = false;

    return 0;
}

/* Funkcja "czyszcząca" odwiedziny, tzn. zmieniająca zmienna odwiedzone na
false. */
void czyszczenie(nand_t *g) {
    for (unsigned i = 0; i < g->ile_wejsc; i++) {
        g->tablica[i].odwiedzone = false;
        if (g->tablica[i].czy_bramka == true &&
            g->tablica[i].odwiedzone == true)
            czyszczenie(g->tablica[i].wchodzace);
    }
}

// Funckja sprawdzająca czy dane są prawidłowe oraz występowanie cyklu.
void czy_poprawne_dane(nand_t *g, int *wynik) {
    if (g->ile_wejsc > 0) {
        bool wszystkie_odwiedzone = true;
        for (unsigned i = 0; i < g->ile_wejsc; i++) {
            if (g->tablica[i].odwiedzone == false) 
            wszystkie_odwiedzone = false;
        }

        if (*wynik == 0 && wszystkie_odwiedzone == false) {
            for (unsigned i = 0; i < g->ile_wejsc; i++) {
                if (g->tablica[i].wchodzace == NULL) {
                    *wynik = 1;
                }
            }

            bool stop = false;
            for (unsigned i = 0; i < g->ile_wejsc && stop == false; i++) {
                if (g->tablica[i].odwiedzone == true)
                    stop = true;

                g->tablica[i].odwiedzone = true;

                if (g->tablica[i].czy_bramka == true)
                    czy_poprawne_dane(g->tablica[i].wchodzace, wynik);

                if (g->tablica[i].czy_bramka == true)
                    czyszczenie(g->tablica[i].wchodzace);
            }
        } 
        else {
            *wynik = 1;
        }
    }
}

/* Funkcja wyznaczająca długość ścieżki krytycznej oraz ustawiająca wartości
sygnałów. */
void wyznaczanie_sciezki_krytycznej(nand_t *g, ssize_t *max, ssize_t akt) {
    if (g->ile_wejsc > 0) {
        akt++;

        if (akt > *max) 
            *max = akt;

        /* Sprawdzam, czy bramka ma w jakimś wejściu inną bramkę. Jeśli okaże
        się, że tak, to wyznaczamy dalej długość ścieżki krytycznej.  */
        bool stop = false;
        unsigned i = 0;
        unsigned j = g->ile_wejsc;
        while (i < j && stop == false) {
            if (g->tablica[i].czy_bramka == true) 
                stop = true;

            i++;
        }
        if (stop == true) {
            for (unsigned i = 0; i < j; i++) {
                if (g->tablica[i].czy_bramka == true)
                    wyznaczanie_sciezki_krytycznej(g->tablica[i].wchodzace, max,
                                                   akt);
            }
        }

        // Wyznaczanie wartości sygnałów.
        for (unsigned i = 0; i < g->ile_wejsc; i++) {
            if (g->tablica[i].czy_bramka == false) {
                bool *pom = g->tablica[i].wchodzace;
                if (*pom == false)
                    g->tablica[i].sygnal = 0;
                else
                    g->tablica[i].sygnal = 1;
            } 
            else {
                nand_t *pomoc = g->tablica[i].wchodzace;
                g->tablica[i].sygnal = pomoc->sygnal;
            }
        }

        bool sygnal = false;
        for (unsigned i = 0; i < g->ile_wejsc; i++)
            if (g->tablica[i].sygnal == 0) sygnal = true;

        if (sygnal == false)
            g->sygnal = 0;
        else
            g->sygnal = 1;
    } 
    else if (g->ile_wejsc == 0)
        g->sygnal = false;
}

ssize_t nand_evaluate(nand_t **g, bool *s, size_t m) {
    if (m == 0) {
        errno = EINVAL;
        return -1;
    }
    if (g == NULL) {
        errno = EINVAL;
        return -1;
    }
    if (s == NULL) {
        errno = EINVAL;
        return -1;
    }

    for (size_t i = 0; i < m; ++i) {
        if (g[i] == NULL) {
            errno = EINVAL;
            return -1;
        }
    }

    // Sprawdzanie poprawności danych.
    int wynik = 0;
    for (size_t i = 0; i < m; i++) {
        if (wynik == 0) {
            czy_poprawne_dane(g[i], &wynik);
            czyszczenie(g[i]);
        }
    }

    // Jeżeli dane są poprawne, to wyznaczamy długość ścieżki krytycznej.
    ssize_t max = 0;
    if (wynik == 0) {
        for (size_t i = 0; i < m; i++) {
            wyznaczanie_sciezki_krytycznej(g[i], &max, 0);
            if (g[i]->sygnal == 0)
                s[i] = false;
            else
                s[i] = true;
        }
    } 
    else {
        errno = ECANCELED;
        return -1;
    }

    return max;
}

ssize_t nand_fan_out(nand_t const *g) {
    if (g == NULL) {
        errno = EINVAL;
        return -1;
    }

    Wyjscia *pom = g->lista;
    ssize_t i = 0;
    while (pom != NULL) {
        i++;
        pom = pom->nast;
    }
    return i;
}

void *nand_input(nand_t const *g, unsigned k) {
    if (g == NULL || k >= g->ile_wejsc) {
        errno = EINVAL;
        return NULL;
    }

    if (g->tablica[k].wchodzace == NULL) {
        errno = 0;
        return NULL;
    }

    void *wynik = g->tablica[k].wchodzace;
    return wynik;
}

nand_t *nand_output(nand_t const *g, ssize_t k) {
    Wyjscia *pom = g->lista;
    for (ssize_t i = 0; i < k; i++) 
        pom = pom->nast;

    return pom->wychodzace;
}