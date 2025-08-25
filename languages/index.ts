/* eslint-disable @typescript-eslint/no-unused-vars */
import { en } from './en';
import { vi } from './vi';

type ExtractParams<S extends string> =
  S extends `${infer _}{${infer Param}}${infer Rest}`
    ? Param | ExtractParams<Rest>
    : never;

type FlattenParams<T, Prefix extends string = ''> = {
  [K in keyof T & (string | number)]: T[K] extends string
    ? {
        key: Prefix extends ''
          ? Extract<K, string>
          : `${Prefix}.${Extract<K, string>}`;
        params: ExtractParams<T[K]>;
      }
    : FlattenParams<
        T[K],
        Prefix extends ''
          ? Extract<K, string>
          : `${Prefix}.${Extract<K, string>}`
      >;
}[keyof T & (string | number)];

export type EnFlattenParams = FlattenParams<typeof en>;

function flatten(obj: any, prefix = ''): Record<string, string> {
  return Object.keys(obj).reduce((acc, key) => {
    const value = obj[key];
    const newKey = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'object' && value !== null) {
      Object.assign(acc, flatten(value, newKey));
    } else {
      acc[newKey] = value;
    }
    return acc;
  }, {} as Record<string, string>);
}

export const languages = {
  en: flatten(en),
  vi: flatten(vi),
};
