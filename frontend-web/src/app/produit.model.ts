/** Représente un produit, identique à l'entité côté Quarkus. */
export interface Produit {
  id?: number;
  nom: string;
  description: string;
  prix: number;
}
