import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Produit } from './produit.model';

/**
 * Service qui dialogue avec l'API Quarkus.
 *
 * On utilise un chemin RELATIF "/api" : c'est Nginx (en prod) ou le proxy
 * de dev d'Angular qui redirige vers le backend. Le navigateur reste donc
 * sur la même origine -> aucun problème de CORS côté web.
 */
@Injectable({ providedIn: 'root' })
export class ProduitService {
  private readonly baseUrl = '/api/produits';

  constructor(private http: HttpClient) { }

  liste(): Observable<Produit[]> {
    return this.http.get<Produit[]>(this.baseUrl);
  }

  creer(produit: Produit): Observable<Produit> {
    return this.http.post<Produit>(this.baseUrl, produit);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
